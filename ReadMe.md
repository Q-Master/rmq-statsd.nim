# StatsD compatible service to collect stats from RabbitMQ

This service is intended to collect some metrics from RabbitMQ using RabbitMQ
management plugin API.

## Service uses libraries:
- [simple StatsD client](https://github.com/Q-Master/statsdclient.nim")
- [packets](https://github.com/Q-Master/packets.nim)

## Currently sent metrics:

- overview
  - object_totals
    - channels
    - queues
    - connections
    - exchanges
    - consumers
  - queue_totals (if enabled)
    - messages
    - messages_ready
    - messages_unacknowledged
  - message_stats
    - ack
    - ack_details.rate
    - deliver
    - deliver_details.rate
    - get
    - get_details.rate
    - redeliver
    - redeliver_details.rate
    - publish
    - publish_details.rate
    - deliver_no_ack
    - deliver_no_ack_details.rate
- nodes (for each node)
  - mem_used
  - fd_used
  - sockets_used
  - disk_free
- queues (if queue_totals disabled)
  - messages
  - messages_ready
  - messages_unacknowledged

## Configuring the daemon
Daemon is supporting the ini format config.
Filename is **rmq_statsd.ini**

### example:
```ini
rmq-url = "http://localhost:15672"
update-interval = 10
statsd = "127.0.0.1:8125"
```

### supported parameters:
| Parameter name | Description | Default value |
|:--------------:|:------------|:--------------:|
| rmq-url | URL to connect to RMQ management plugin  |    http://localhost:15672    |
| rmq-user | user name to connect to RMQ management plugin  | guest |
| rmq-password | password to connect to RMQ management plugin | guest |
| statsd | UDP address to send data to StatsD-compatible service | 127.0.0.1:8125 |
| update-interval | interval in seconds to query RMQ for updates | 30 |


## Building and installation
To build this daemon you either should install nim toolchain see [Nim installation](https://nim-lang.org/install.html) or use a supplied docker file.

### Manual building
To build daemon you should use

**Debug mode**
```bash
nimble build
```

**Release mode**
```bash
nimble build -d:release -l:"-flto" -t:"-flto" --opt:size --threads:on
objcopy --strip-all -R .comment -R .comments  rmq-statsd
```

### Docker building
Docker building requires the preconfigured rmq-statsd.ini file to be in the current directory.
```bash
docker build --target release -t rmq-statsd .
```