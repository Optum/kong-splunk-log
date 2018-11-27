local basic_serializer = require "kong.plugins.kong-splunk-log.basic"
local BasePlugin = require "kong.plugins.base_plugin"
local LuaProducer = require "kong.plugins.kong-splunk-log.lua_producer"
local JSONProducer = require "kong.plugins.kong-splunk-log.json_producer"
local Sender = require "kong.plugins.kong-splunk-log.sender"
local Buffer = require "kong.plugins.kong-splunk-log.buffer"
local cjson = require "cjson"

local cjson_encode = cjson.encode
local ERR = ngx.ERR


local KongSplunkLog = BasePlugin:extend()

KongSplunkLog.PRIORITY = 12
KongSplunkLog.VERSION = "0.1.5"


local buffers = {} -- buffers per-route / -api


-- Only provide `name` when deriving from this class. Not when initializing an instance.
function KongSplunkLog:new(name)
  name = name or "kong-splunk-log"
  KongSplunkLog.super.new(self, name)

  self.ngx_log = ngx.log
--  self.ngx_log = function(lvl, ...)
--    ngx_log(lvl, "[", name, "] ", ...)
--  end

  self.name = name
end


-- serializes context data into an html message body.
-- @param `ngx` The context table for the request being logged
-- @param `conf` plugin configuration table, holds http endpoint details
-- @return html body as string
function KongSplunkLog:serialize(ngx, conf)
  return cjson_encode(basic_serializer.serialize(ngx))
end


function KongSplunkLog:log(conf)
  KongSplunkLog.super.log(self)

  local route_id 
  if ngx.ctx.route then
    route_id = ngx.ctx.route.id
  else
    route_id = "notfound" 
  end
  
  local buf = buffers[route_id]
  if not buf then

    if conf.queue_size == nil then
      conf.queue_size = 1
    end

    -- base delay between batched sends
    conf.send_delay = 0

    local buffer_producer
    -- If using a queue, produce messages into a JSON array,
    -- otherwise keep it as a 1-entry Lua array which will
    -- result in a backward-compatible single-object HTTP request.
    if conf.queue_size > 1 then
      buffer_producer = JSONProducer.new(true)
    else
      buffer_producer = LuaProducer.new()
    end

    local err
    buf, err = Buffer.new(self.name, conf, buffer_producer, Sender.new(conf, self.ngx_log), self.ngx_log)
    if not buf then
      self.ngx_log(ERR, "could not create buffer: ", err)
      return
    end
    buffers[route_id] = buf
  end

  -- This can be simplified if we don't expect third-party plugins to
  -- "subclass" this plugin.
  buf:add_entry(self:serialize(ngx, conf))
end

return KongSplunkLog
