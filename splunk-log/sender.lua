local url = require "socket.url"
local http = require "resty.http"
local sender = {}
local ngx_encode_base64 = ngx.encode_base64
local ERR = ngx.ERR
local sub = string.sub
local gsub = string.gsub

-- Parse host url.
-- @param `url` host url
-- @return `parsed_url` a table with host details like domain name, port, path etc
local function parse_url(host_url)
  local parsed_url = url.parse(host_url)
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
  return parsed_url
end

-- Log to a Http end point.
-- @param `bodies` raw http bodies to be logged
local function send(self, bodies)
  local log = self.log

  local ok, err
  local parsed_url = parse_url(self.http_endpoint)
  local host = parsed_url.host
  local port = tonumber(parsed_url.port)

  if type(bodies) == "string" then
    bodies = { bodies }
  end
  for _, body in ipairs(bodies) do
  
    --Convert to splunk batch format is queue_size > 1
    if self.queue_size > 1 then
      body = gsub(sub(body, 2,-2), "},{\"host\"", "}\n\n{\"host\"")
    end
  
    local httpc = http.new()
    httpc:set_timeout(self.timeout)
    ok, err = httpc:connect(host, port)
    if not ok then
      log(ERR, "failed to connect to ", host, ":", tostring(port), ": ", err)
      return false
    end

    if parsed_url.scheme == "https" then
      local _, err = httpc:ssl_handshake(true, host, false)
      if err then
        log(ERR, "failed to do SSL handshake with ",
                 host, ":", tostring(port), ": ", err)
        return false
      end
    end

    local res, err = httpc:request({
      method = self.method,
      path = parsed_url.path,
      query = parsed_url.query,
      headers = {
        ["Host"] = parsed_url.host,
        ["Content-Type"] = self.content_type,
        ["Content-Length"] = #body,
        ["Authorization"] = "Splunk " .. self.splunk_access_token,
      },
      body = body,
    })
    if not res then
      log(ERR, "failed request to ", host, ":", tostring(port), ": ", err)
      httpc:set_keepalive(self.keepalive)
      return false
    end
    
    -- read and discard body
    -- TODO should we fail if response status was >= 500 ?
    res:read_body()
    if res.status ~= 200 then
       log(ERR, "Error: Splunk returned status code: ",  tostring(res.status))
    end      

    ok, err = httpc:set_keepalive(self.keepalive)
    if not ok then
      log(ERR, "failed keepalive for ", host, ":", tostring(port), ": ", err)
    end
  end

  return true
end

function sender.new(conf, log)
  if type(log) ~= "function" then
    error("arg #2 (log) must be a function")
  end

  local self = {
    http_endpoint = conf.splunk_endpoint,
    content_type = conf.content_type,
    keepalive = conf.keepalive,
    timeout = conf.timeout,
    method = conf.method,
    splunk_access_token = conf.splunk_access_token,
    queue_size = conf.queue_size,
    
    send = send,
    log = log,
  }

  return self
end

return sender
