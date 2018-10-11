package = "kong-splunk-log-stoneco"
version = "0.1.0-0"
source = {
   url = "git+https://github.com/Optum/kong-splunk-log.git"
}
description = {
   summary = "Kong plugin designed to log API transactions to Splunk",
   detailed = [[
    Kong provides many great logging tools out of the box, this is a modified version of the Kong HTTP logging plugin that has been refactored and tailored to work with Splunk.
    Please see here for more info: https://github.com/Optum/kong-splunk-log
   ]],
   homepage = "https://github.com/Optum/kong-splunk-log",
   license = "Apache 2.0"
}
dependencies = {}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.kong-splunk-log-stoneco.basic"] = "./basic.lua",
      ["kong.plugins.kong-splunk-log-stoneco.handler"]  = "./handler.lua",
      ["kong.plugins.kong-splunk-log-stoneco.schema"]= "./schema.lua"
   }
}
