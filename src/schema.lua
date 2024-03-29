local typedefs = require "kong.db.schema.typedefs"

return {
  name = "kong-splunk-log",
  fields = {
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          -- NOTE: any field added here must be also included in the handler's get_queue_id method
          { splunk_endpoint = typedefs.url({ required = true }) },
          { splunk_access_token = { type = "string", default = "aaaaaaaa-bbbb-cccc-dddd-ffffffffffff", }, },
          { method = { type = "string", default = "POST", one_of = { "POST", "PUT", "PATCH" }, }, },
          { content_type = { type = "string", default = "application/json", one_of = { "application/json" }, }, },
          { timeout = { type = "number", default = 10000 }, },
          { keepalive = { type = "number", default = 60000 }, },
          { retry_count = { type = "integer" }, },
          { queue_size = { type = "integer" }, },
          { flush_timeout = { type = "number" }, },
          { queue = typedefs.queue },
    }, }, },
  },
}
