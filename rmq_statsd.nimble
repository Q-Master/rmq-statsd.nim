# Package

version       = "0.2.1"
author        = "Vladimir Berezenko"
description   = "Pure nim rabbitmq to statsd metrics pusher"
license       = "MIT"
srcDir        = "src"
namedBin["rmq_statsd"] = "rmq-statsd"

# Dependencies

requires "nim >= 2.0.0"
requires "amqpstats >= 0.2.0"
requires "simplestatsdclient >= 0.2.0"
