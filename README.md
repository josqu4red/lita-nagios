# lita-nagios

[![Build Status](https://travis-ci.org/josqu4red/lita-nagios.png?branch=master)](https://travis-ci.org/josqu4red/lita-nagios)
[![Coverage Status](https://coveralls.io/repos/josqu4red/lita-nagios/badge.png)](https://coveralls.io/r/josqu4red/lita-nagios)

**lita-nagios** is a handler for [Lita](https://github.com/jimmycuadra/lita) that allows interaction with Nagios monitoring solution.
It listens for notifications on a HTTP endpoint and uses [nagiosharder](https://github.com/railsmachine/nagiosharder) to send commands to the Nagios instance.

Note: Colors in notifications are not enabled yet, because it relies completely on the adapter and no abstraction layer is implemented nor designed as of now.

## Installation

Add lita-nagios to your Lita instance's Gemfile:

``` ruby
gem "lita-nagios"
```

## Configuration

### HTTP interface
* `default_room` (String) - Default chat room for notifications

### Nagios commands (`nagiosharder` config)
* `cgi` - Nagios CGI URL
* `user` - Nagios user with system commands authorization
* `pass` - User password
* `version` - Nagios version, default: 3
* `time_format` - default: "iso8601"
* `verify_ssl` - default: `true`

### Example

``` ruby
Lita.configure do |config|
  config.handlers.nagios.default_room = "#admin_room"
  config.handlers.nagios.cgi = "http://nagios.example.com/cgi-bin/nagios3"
  config.handlers.nagios.user = "lita"
  config.handlers.nagios.pass = "xxxx"
  config.handlers.nagios.version = 3
  config.handlers.nagios.time_format = "iso8601"
  config.handlers.nagios.verify_ssl = true
end
```

## Usage

### Display notifications in channel

lita-nagios provides a HTTP endpoint to receive Nagios notifications:

```
POST /nagios/notifications
```
Request parameters must include those fields:
* `type` - `host` or `service`
* `room` - notifications destination (see `default_room` in configuration section)
* `host` - Nagios' $HOSTNAME$ or $HOSTALIAS$
* `output` - Nagios' $HOSTOUTPUT$ or $SERVICEOUTPUT$
* `state` - Nagios' $HOSTSTATE$ or $SERVICESTATE$
* `notificationtype` - Nagios' $NOTIFICATIONTYPE$
* `description` - Nagios' $SERVICEDESC$ (only for `service` type)

An example Nagios configuration (contact, commands) to send alerts to channels is provided in [contrib](contrib/nagios_config.txt) folder

### Send commands to Nagios

```
lita: nagios enable notif(ication(s)) <-h | --host HOST> [-s | --service SERVICE] - Enable notifications for given host/service
lita: nagios disable notif(ication(s)) <-h | --host HOST> [-s | --service SERVICE] - Disable notifications for given host/service
lita: nagios recheck <-h | --host HOST> [-s | --service SERVICE] - Reschedule check for given host/service
lita: nagios ack(nowledge) <-h | --host HOST> [-s | --service SERVICE] [-m | --message MESSAGE] - Acknowledge host/service problem with optional message
lita: nagios (fixed|flexible) downtime <-d | --duration DURATION > <-h | --host HOST> [-s | --service SERVICE] - Schedule downtime for a host/service with duration units in (m, h, d, default to seconds)
```

## License

[MIT](http://opensource.org/licenses/MIT)
