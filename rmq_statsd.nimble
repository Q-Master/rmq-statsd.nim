# Package

version       = "0.1.0"
author        = "Vladimir Berezenko"
description   = "Pure nim rabbitmq to statsd metrics pusher"
license       = "MIT"
srcDir        = "src"
namedBin["rmq_statsd"] = "rmq-statsd"

# Dependencies

requires "nim >= 2.0.0", "amqpstats >= 0.1.1", "simplestatsdclient >= 0.1.0"
