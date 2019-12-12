local tablex = require "pl.tablex"
local _M = {}
local EMPTY = tablex.readonly({})
local splunkHost= os.getenv("SPLUNK_HOST")
local gkong = kong

function _M.serialize(ngx, kong)
  local ctx = ngx.ctx
  local var = ngx.var
  local req = ngx.req

  if not kong then
    kong = gkong
  end
  
  -- Handles Nil Users
  local ConsumerUsername
  if ctx.authenticated_consumer ~= nil then
    ConsumerUsername = ctx.authenticated_consumer.username
  end
    
  local PathOnly
  if var.request_uri ~= nil then
      PathOnly = string.gsub(var.request_uri,"%?.*","")
  end
    
  local UpstreamPathOnly
  if var.upstream_uri ~= nil then
      UpstreamPathOnly = string.gsub(var.upstream_uri,"%?.*","")
  end

  local RouteUrl
  if ctx.balancer_data ~= nil then 
      RouteUrl = ctx.balancer_data.host .. ":" .. ctx.balancer_data.port .. UpstreamPathOnly
  end

  local serviceName
  --Service Resource (Kong >= 0.13.0)
  if ctx.service ~= nil then
        serviceName = ctx.service.name
  end

  return {
      host = splunkHost,
      source = var.hostname,
      sourcetype = "AccessLog",
      time = req.start_time(),
      event = {   
        CID = req.get_headers()["optum-cid-ext"],
          HTTPMethod = kong.request.get_method(),
          RequestSize = var.request_length,
          RoutingURL = RouteUrl,
          HTTPStatus = ngx.status,
      ErrorMsg = kong.ctx.shared.errmsg,
          GatewayHost = var.host,
      Tries = (ctx.balancer_data or EMPTY).tries, --contains the list of (re)tries (successes and failures) made by the load balancer for this request
          ResponseSize = var.bytes_sent,
          BackendLatency = ctx.KONG_WAITING_TIME or -1, -- is the time it took for the final service to process the request
          TotalLatency = var.request_time * 1000, --  is the time elapsed between the first bytes were read from the client and after the last bytes were sent to the client. Useful for detecting slow clients
      KongLatency = {
        AccessTime = (ctx.KONG_ACCESS_TIME or 0),     --Access phase, majority of Kong plugins
        ReceiveTime = (ctx.KONG_RECEIVE_TIME or 0),   --Time it took before Kong had fully recieved all headers and response body from backend
        RewriteTime = (ctx.KONG_REWRITE_TIME or 0),   --Rewrite phase (between Kong has response and time spent before returning it to client)
        BalancerTime = (ctx.KONG_BALANCER_TIME or 0)  --Balancer time, DNS or upstream/target logic Kong hot paths here
      },
          Consumer = ConsumerUsername,
          ClientIP = var.remote_addr,
          URI = PathOnly,
          ServiceName = serviceName,
      }
  }
end

return _M
