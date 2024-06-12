# Kong Splunk Log

## :warning: Notice :warning:



<b>We have decided to update this plugin one last time for Kong 3.7 compatibility. But going forward this repo/plugin will no longer be maintained. In the future we recommend using a modified http-log plugin paired with
a modified Kong pdk log serializer patch file going forward.</b>

See https://docs.konghq.com/hub/kong-inc/http-log/how-to/splunk/ for more information

## Overview
Kong plugin designed to log API transactions to Splunk using the Splunk HTTP collector.

Kong provides many great logging tools out of the box, this is a modified version of the Kong HTTP logging plugin that has been refactored and tailored to work with Splunk.

Example Event Log Transaction:

![Splunk Sample](https://github.com/Optum/kong-splunk-log/blob/master/SplunkLogSample.png)

## Supported Kong Releases
Kong >= 3.x

## Installation
Recommended:
```
$ luarocks install kong-splunk-log
```
Other:
```
$ git clone https://github.com/Optum/kong-splunk-log.git /path/to/kong/plugins/kong-splunk-log
$ cd /path/to/kong/plugins/kong-splunk-log
$ luarocks make *.rockspec
```

## Configuration
The plugin requires an environment variable `SPLUNK_HOST` . This is how we define the host="" splunk field in the example log picture embedded above in our README.

Example Plugin Configuration:

![Splunk Config](https://github.com/Optum/kong-splunk-log/blob/master/SplunkConfig.png)

If not already set, it can be done so as follows:
```
$ export SPLUNK_HOST="gateway.company.com"
```

**One last step** is to make the environment variable accessible by an nginx worker. To do this, simply add this line to your _nginx.conf_
```
env SPLUNK_HOST;
```

## Maintainers
[jeremyjpj0916](https://github.com/jeremyjpj0916)  
[rsbrisci](https://github.com/rsbrisci)  

Feel free to open issues, or refer to our [Contribution Guidelines](https://github.com/Optum/kong-splunk-log/blob/master/CONTRIBUTING.md) if you have any questions.
