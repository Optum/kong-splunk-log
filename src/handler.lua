local basic_serializer = require "kong.plugins.kong-splunk-log.basic"
local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"
local url = require "socket.url"
local string_format = string.format
local cjson_encode = cjson.encode
local KongSplunkLog = BasePlugin:extend()

KongSplunkLog.PRIORITY = 12
KongSplunkLog.VERSION = "0.1.0"

local HTTP = "http"
local HTTPS = "https"

local function generate_post_payload(method, content_type, parsed_url, body, splunk_access_token)
  local url
  if parsed_url.query then
    url = parsed_url.path .. "?" .. parsed_url.query
  else
    url = parsed_url.path
  end
  local headers = string_format(
    "%s %s HTTP/1.1\r\nHost: %s\r\nConnection: Keep-Alive\r\nContent-Type: %s\r\nContent-Length: %s\r\n",
    method:upper(), url, parsed_url.host, content_type, #body)
  
  if splunk_access_token ~= nil then
    local auth_header = string_format("Authorization: Splunk %s\r\n",splunk_access_token)
    headers = headers .. auth_header
  end

  return string_format("%s\r\n%s", headers, body)
end

local function parse_url(host_url)
  local parsed_url = url.parse(host_url)
  if not parsed_url.port then
    if parsed_url.scheme == HTTP then
      parsed_url.port = 80
     elseif parsed_url.scheme == HTTPS then
      parsed_url.port = 443
     end
  end
  if not parsed_url.path then
    parsed_url.path = "/"
  end
  return parsed_url
end

local function log(premature, conf, body, name)
  if premature then
    return
  end
  name = "[" .. name .. "] "
  local ok, err
  local parsed_url = parse_url(conf.splunk_endpoint)
  local host = parsed_url.host
  local port = tonumber(parsed_url.port)
  local sock = ngx.socket.tcp()
  sock:settimeout(conf.timeout)

  ok, err = sock:connect(host, port)
  if not ok then
    ngx.log(ngx.ERR, name .. "failed to connect to " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end

  if parsed_url.scheme == HTTPS then
    local _, err = sock:sslhandshake(true, host, false)
    if err then
      ngx.log(ngx.ERR, name .. "failed to do SSL handshake with " .. host .. ":" .. tostring(port) .. ": ", err)
    end
  end

  ok, err = sock:send(generate_post_payload(conf.method, conf.content_type, parsed_url, body, conf.splunk_access_token))
  if not ok then
    ngx.log(ngx.ERR, name .. "failed to send data to " .. host .. ":" .. tostring(port) .. ": ", err)
  end
  
end

-- Only provide `name` when deriving from this class. Not when initializing an instance.
function KongSplunkLog:new(name)
  KongSplunkLog.super.new(self, name or "optum-kong-http-log-plugin")
end

function KongSplunkLog:serialize(ngx, conf)
  return cjson_encode(basic_serializer.serialize(ngx))
end

function KongSplunkLog:log(conf)
  KongSplunkLog.super.log(self)

  local ok, err = ngx.timer.at(0, log, conf, self:serialize(ngx, conf), self._name)
  if not ok then
    ngx.log(ngx.ERR, "[" .. self._name .. "] failed to create timer: ", err)
  end
end

return KongSplunkLog
