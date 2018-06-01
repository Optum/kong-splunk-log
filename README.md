# Kong Splunk Log
## Overview
Kong plugin designed to log API transactions to Splunk.

Kong provides many great logging tools out of the box, this is an adapted version of the Kong HTTP logging plugin that has been refactored and tailored to work with Splunk.

Example Log Transaction:


## Supported Kong Releases
Kong >= 0.12.x 

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
The plugin requires an environment variable `SPLUNK_HOST` . This is how we define the host="" splunk field in the example log picture embedded in our README.

If not already set, it can be done so as follows:
```
$ export SPLUNK_HOST="/path/to/kong/ssl/privatekey.key"
```

**One last step** is to make the environment variable accessible by an nginx worker. To do this, simply add these line to your _nginx.conf_
```
env SPLUNK_HOST;
```

Feel free to open issues, or refer to our Contribution Guidelines if you have any questions.
