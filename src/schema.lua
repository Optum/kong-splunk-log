return {
  fields = {
    splunk_endpoint = { required = true,  default = "https://hec-splunk.company.com/services/collector", type="url"},
    method = { default = "POST", enum = { "POST", "PUT", "PATCH" } },
    content_type = { default = "application/json", enum = { "application/json" } },
    timeout = { default = 10000, type = "number" },
    keepalive = { default = 60000, type = "number" },
    splunk_access_token = { default = "aaaaaaaa-bbbb-cccc-dddd-ffffffffffff", type="text"},
    retry_count = { default = 5, type = "number" },
    queue_size = { default = 20, type = "number" },
    flush_timeout = { default = 30, type = "number" }
  }
}
