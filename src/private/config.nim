import std/[parsecfg, strutils, nativesockets]

type
  AMQPStatsdConfig* = object
    rmqURL*: string
    rmqUser*: string
    rmqPasswd*: string
    statsdHost*: string
    statsdPort*: Port
    updateInterval*: int


proc initConfig(
  rmqURL: string = "http://localhost:15672",
  rmqUser: string = "guest",
  rmqPasswd: string = "guest",
  updateInterval: int = 10,
  statsd: string = "127.0.0.1:8125",
  ): AMQPStatsdConfig =
  result.rmqURL = rmqURL
  result.rmqUser = rmqUser
  result.rmqPasswd = rmqPasswd
  var splits = statsd.rsplit(':', maxSplit=1)
  if splits.len == 1:
    result.statsdHost = splits[0]
    result.statsdPort = Port(8125)
  else:
    result.statsdHost = splits[0]
    result.statsdPort = Port(parseBiggestInt(splits[1]))
  result.updateInterval = updateInterval*1000

  echo "--- Current configuration ---"
  echo "RMQ URL ", result.rmqURL
  echo "RMQ User ", result.rmqUser
  echo "StatsD ", result.statsdHost, ":", result.statsdPort
  echo "---"


proc readConfig*(): AMQPStatsdConfig =
  try:
    let conf = loadConfig("rmq_statsd.ini")
    result = initConfig(
      rmqURL = conf.getSectionValue("", "rmq-url", "http://localhost:15672"),
      rmqUser = conf.getSectionValue("", "rmq-user", "guest"),
      rmqPasswd = conf.getSectionValue("", "rmq-password", "guest"),
      updateInterval = parseBiggestInt(conf.getSectionValue("", "update-interval", "30")),
      statsd = conf.getSectionValue("", "statsd", "127.0.0.1:8125"),
    )
  except IOError as e:
    echo "Error reading config (", e.msg, "). Using defaults."
    result = initConfig()