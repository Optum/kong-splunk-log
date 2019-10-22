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

  local PathOnly
  if ngx.var.request_uri ~= nil then
      PathOnly = string.gsub(ngx.var.request_uri,"%?.*","")
  end

  local UpstreamPathOnly
  if ngx.var.upstream_uri ~= nil then
      UpstreamPathOnly = string.gsub(ngx.var.upstream_uri,"%?.*","")
  end

  local RouteUrl
  if ngx.ctx.balancer_data ~= nil then
      RouteUrl = ngx.ctx.balancer_data.host .. ":" .. ngx.ctx.balancer_data.port .. UpstreamPathOnly
  end

  local serviceName
  --Service Resource (Kong >= 0.13.0)
  if ngx.ctx.service ~= nil then
        serviceName = ngx.ctx.service.name
  end

  return {
  	host = splunkHost,
  	source = ngx.var.hostname,
  	sourcetype = "AccessLog",
	  time = ngx.time(),
    event = {
      request = {
        uri = ngx.var.request_uri,
        url = ngx.var.scheme .. "://" .. ngx.var.host .. ":" .. ngx.var.server_port .. ngx.var.request_uri,
        querystring = ngx.req.get_uri_args(), -- parameters, as a table
        method = ngx.req.get_method(), -- http method
        headers = ngx.req.get_headers(),
        size = ngx.var.request_length
      },
      upstream_uri = ngx.var.upstream_uri,
      response = {
        status = ngx.status,
        headers = ngx.resp.get_headers(),
        size = ngx.var.bytes_sent
      },
      tries = (ngx.ctx.balancer_address or EMPTY).tries,
      latencies = {
        kong = (ngx.ctx.KONG_ACCESS_TIME or 0) + (ngx.ctx.KONG_RECEIVE_TIME or 0) + (ngx.ctx.KONG_REWRITE_TIME or 0) +
          (ngx.ctx.KONG_BALANCER_TIME or 0),
        proxy = ngx.ctx.KONG_WAITING_TIME or -1,
        request = ngx.var.request_time * 1000
      },
      authenticated_entity = authenticated_entity,
      route = ngx.ctx.route,
      service = ngx.ctx.service,
      api = ngx.ctx.api,
      consumer = ngx.ctx.authenticated_consumer,
      client_ip = ngx.var.remote_addr,
      started_at = ngx.req.start_time() * 1000
    }
end

return _M
