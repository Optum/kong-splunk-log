local basic_serializer = require "kong.plugins.kong-splunk-log.basic"
local Queue = require "kong.tools.queue"
local cjson = require "cjson"
local url = require "socket.url"
local http = require "resty.http"
local cjson_encode = cjson.encode
local ngx_encode_base64 = ngx.encode_base64
local table_concat = table.concat
local tostring = tostring
local tonumber = tonumber
local fmt = string.format
local pairs = pairs
local max = math.max

local KongSplunkLog = {}

KongSplunkLog.PRIORITY = 12
KongSplunkLog.VERSION = "3.9.0"

local function json_array_concat(entries)
  --return "[" .. table_concat(entries, ",") .. "]" If splunk followed true json format we would use this
    return "" .. table_concat(entries, "\n\n") .. "" -- Break events up by newlining them
end

-- Create a function that concatenates multiple JSON objects into a JSON array.
-- This saves us from rendering all entries into one large JSON string.
-- Each invocation of the function returns the next bit of JSON, i.e. the opening
-- bracket, the entries, delimiting commas and the closing bracket.
-- UPDATE: Edited to not have leading/trailing []'s and no commas between entries for splunk format logging.
local function make_splunk_json_array_payload_function(conf, entries)
  if conf.queue.max_batch_size == 1 then
    return #entries[1], entries[1]
  else
    local payload = json_array_concat(entries)
    return #payload, payload
  end
end


local parsed_urls_cache = {}
-- Parse host url.
-- @param `url` host url
-- @return `parsed_url` a table with host details:
-- scheme, host, port, path, query, userinfo
local function parse_url(host_url)
  local parsed_url = parsed_urls_cache[host_url]

  if parsed_url then
    return parsed_url
  end

  parsed_url = url.parse(host_url)
  if not parsed_url.port then
    if parsed_url.scheme == "http" then
      parsed_url.port = 80

    elseif parsed_url.scheme == "https" then
      parsed_url.port = 443
    end
  end
  if not parsed_url.path then
    parsed_url.path = "/"
  end

  parsed_urls_cache[host_url] = parsed_url

  return parsed_url
end


-- Sends the provided payload (a string) to the configured plugin host
-- @return true if everything was sent correctly, falsy if error
-- @return error message if there was an error
local function send_payload(conf, entries)
  local method = conf.method
  local timeout = conf.timeout
  local keepalive = conf.keepalive
  local content_type = conf.content_type
  local http_endpoint = conf.splunk_endpoint
  local splunk_token = conf.splunk_access_token

  local ok, err
  local parsed_url = parse_url(http_endpoint)
  local host = parsed_url.host
  local port = tonumber(parsed_url.port)

  local httpc = http.new()
  httpc:set_timeout(timeout)
  ok, err = httpc:connect(host, port)
  if not ok then
    return nil, "failed to connect to " .. host .. ":" .. tostring(port) .. ": " .. err
  end

  if parsed_url.scheme == "https" then
    local _, err = httpc:ssl_handshake(true, host, false)
    if err then
      return nil, "failed to do SSL handshake with " ..
                  host .. ":" .. tostring(port) .. ": " .. err
    end
  end

  local content_length, payload = make_splunk_json_array_payload_function(conf, entries)

  local res, err = httpc:request({
    method = method,
    path = parsed_url.path,
    query = parsed_url.query,
    headers = {
      ["Host"] = parsed_url.host,
      ["Content-Type"] = content_type,
      ["Content-Length"] = content_length,
      ["Authorization"] = "Splunk " .. splunk_token,
    },
    body = payload,
  })
  if not res then
    return nil, "failed request to " .. host .. ":" .. tostring(port) .. ": " .. err
  end

  -- always read response body, even if we discard it without using it on success
  local response_body = res:read_body()
  local success = res.status < 400
  local err_msg

  if not success then
    err_msg = "request to " .. host .. ":" .. tostring(port) ..
              " returned status code " .. tostring(res.status) .. " and body " ..
              response_body
  end

  ok, err = httpc:set_keepalive(keepalive)
  if not ok then
    -- the batch might already be processed at this point, so not being able to set the keepalive
    -- will not return false (the batch might not need to be reprocessed)
    kong.log.err("failed keepalive for ", host, ":", tostring(port), ": ", err)
  end

  return success, err_msg
end

-- Create a queue name from the same legacy parameters that were used in the
-- previous queue implementation.  This ensures that http-log instances that
-- have the same log server parameters are sharing a queue.  It deliberately
-- uses the legacy parameters to determine the queue name, even though they may
-- be nil in newer configurations.  Note that the modernized queue related
-- parameters are not included in the queue name determination.
local function make_queue_name(conf)
  return fmt("%s:%s:%s:%s:%s:%s",
    conf.splunk_endpoint,
    conf.method,
    conf.content_type,
    conf.timeout,
    conf.keepalive,
    conf.retry_count,
    conf.queue_size,
    conf.flush_timeout)
end


function KongSplunkLog:log(conf)

  local queue_conf = Queue.get_plugin_params("kong-splunk-log", conf, make_queue_name(conf))
  kong.log.debug("Queue name automatically configured based on configuration parameters to: ", queue_conf.name)

  local ok, err = Queue.enqueue(
    queue_conf,
    send_payload,
    conf,
    cjson_encode(basic_serializer.serialize(ngx))
  )
  if not ok then
    kong.log.err("Failed to enqueue log entry to log server: ", err)
  end
end

return KongSplunkLog
