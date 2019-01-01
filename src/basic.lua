local tablex = require "pl.tablex"
local _M = {}
local EMPTY = tablex.readonly({})
local splunkHost= os.getenv("SPLUNK_HOST")

function _M.serialize(ngx)
  -- Handles Nil Users
  local ConsumerUsername
  if ngx.ctx.authenticated_consumer ~= nil then
    ConsumerUsername = ngx.ctx.authenticated_consumer.username
  end

  local RouteUrl
  if ngx.ctx.balancer_data ~= nil then 
      RouteUrl = ngx.ctx.balancer_data.host .. ":" .. ngx.ctx.balancer_data.port .. string.gsub(ngx.var.upstream_uri,"%?.*","")
  end

  local serviceName
  --Service Resource (Kong >= 0.13.0)
  if ngx.ctx.service ~= nil then
        serviceName = ngx.ctx.service.name
  end

  return {
  	host=splunkHost,
  	source=ngx.var.hostname,
  	sourcetype="AccessLog",
	time = ngx.time(),
  	event={   
	          CID = ngx.req.get_headers()["optum-cid-ext"],
		  HTTPMethod = ngx.req.get_method(),
		  RequestSize = ngx.var.request_length,
		  RoutingURL = RouteUrl,
		  HTTPStatus = ngx.status,
                  ErrorMsg = kong.ctx.shared.errmsg,
		  GatewayHost = ngx.var.host,
                  Tries = (ngx.ctx.balancer_data or EMPTY).tries, --contains the list of (re)tries (successes and failures) made by the load balancer for this request
		  ResponseSize = ngx.var.bytes_sent,
		  BackendLatency = ngx.ctx.KONG_WAITING_TIME or -1, -- is the time it took for the final service to process the request
		  TotalLatency = ngx.var.request_time * 1000, --  is the time elapsed between the first bytes were read from the client and after the last bytes were sent to the client. Useful for detecting slow clients
                  Consumer = ConsumerUsername,
		  ClientIP = ngx.var.remote_addr,
		  URI = string.gsub(ngx.var.request_uri,"%?.*",""),
		  ServiceName = serviceName,
	      }
  }
end

return _M
