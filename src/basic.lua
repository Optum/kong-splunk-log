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

  local RouteUrl = ""
  if ctx.balancer_data ~= nil then
      if ctx.balancer_data.host ~= nil then
        RouteUrl = ctx.balancer_data.host
      end

      if ctx.balancer_data.port ~= nil then
        RouteUrl = RouteUrl .. ":" .. ctx.balancer_data.port
      end

      if UpstreamPathOnly ~= nil then
        RouteUrl = RouteUrl .. UpstreamPathOnly
      end
  end

  local serviceName
  local appId
  --Service Resource (Kong >= 0.13.0)
  if ctx.service ~= nil then
    serviceName = ctx.service.name

    if ctx.service.tags ~= nil then
      --Find app id tag. Tags are like: [key:value, key:value]
      for _, tag in ipairs(ctx.service.tags) do
        local values = {}
        local index = 0
        for token in string.gmatch(tag, "[^:]+") do
          values[index] = token
          index = index + 1
        end

        if (index == 2 and values[0] == "appId") then
          appId = values[1]
          break
        end
      end
    end
  end

  return {
      host = splunkHost,
      source = var.hostname,
      sourcetype = "AccessLog",
      time = req.start_time(), -- Contains the UTC timestamp of when the request has started to be processed. No rounding like StartedAt + lacks ctx.KONG_PROCESSING_START as possible return(look for discrepancies maybe sometime?).
      event = {   
          CID = kong.request.get_header("optum-cid-ext"),
          FrontDoorRef = req.get_headers()["X-Azure-Ref"],
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
          KongLatency = (ctx.KONG_PROXY_LATENCY or ctx.KONG_RESPONSE_LATENCY or 0) + (ctx.KONG_RECEIVE_TIME or 0), -- is the internal Kong latency that it took to run all the plugins
          StartedAt = ctx.KONG_PROCESSING_START or (req.start_time() * 1000), -- Contains the UTC timestamp of when the request had started to be processed.
          Consumer = ConsumerUsername,
          ClientIP = var.remote_addr,
          URI = PathOnly,
          ServiceName = serviceName,
          GatewayPort = ((var.server_port == "8443" or var.server_port == "8000") and "443" or "8443"),
          ClientCertEnd = var.ssl_client_v_end,
          AppId = appId,
      }
  }
end

return _M
