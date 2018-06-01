package = "kong-splunk-log"
version = "0.1-1"
source = {
   url = "git+https://github.com/Optum/kong-splunk-log.git"
}
description = {
   summary = "Kong plugin designed to log API transactions to Splunk",
   detailed = [[
   
   ]],
   homepage = "https://github.com/Optum/kong-splunk-log",
   license = "Apache 2.0"
}
dependencies = {}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.kong-splunk-log.basic"] = "src/basic.lua",
      ["kong.plugins.kong-splunk-log.handler"]  = "src/handler.lua",
      ["kong.plugins.kong-splunk-log.schema"]= "src/schema.lua"
   }
}
