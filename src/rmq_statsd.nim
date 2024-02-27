import std/[exitprocs, options, os]
import amqpstats, simplestatsdclient
import private/config


const SLEEP_TIME = 500


type
  Self = object
    config: AMQPStatsdConfig
    statsM: AMQPStats
    statsDM: StatsDClient


var running: bool = true
var self {.noinit.}: Self


proc atExit() {.noconv.} =
  running = false
  echo "Stopping application"


proc onTimerEvent() =
  try:
    let overview = self.statsM.overview()
    let nodes = self.statsM.nodes()
    
    try:
      self.statsDM.gauge("rabbitmq." & overview.node & ".channels", overview.objectTotals.channels)
      self.statsDM.gauge("rabbitmq." & overview.node & ".queues", overview.objectTotals.queues)
      self.statsDM.gauge("rabbitmq." & overview.node & ".connections", overview.objectTotals.connections)
      self.statsDM.gauge("rabbitmq." & overview.node & ".consumers", overview.objectTotals.consumers)
      self.statsDM.gauge("rabbitmq." & overview.node & ".exchanges", overview.objectTotals.exchanges)

      if overview.enableQueueTotals:
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.messages", overview.queueTotals.messages.get(0))
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.ready", overview.queueTotals.messagesReady.get(0))
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.unack", overview.queueTotals.messagesUnacknowledged.get(0))
      else:
        let queues = self.statsM.queues()
        var messages: int = 0
        var messagesReady: int = 0
        var messagesUnack: int = 0
        for queue in queues:
          messages.inc(queue.messages.get(0))
          messagesReady.inc(queue.messagesReady.get(0))
          messagesUnack.inc(queue.messagesUnacknowledged.get(0))
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.messages", messages)
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.ready", messagesReady)
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.unack", messagesUnack)

      if overview.messageStats.isSome:
        let ms = overview.messageStats.get
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.ack", ms.ack)
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.ack_rate", ms.ackDetails.rate)
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.deliver", ms.deliver)
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.deliver_rate", ms.deliverDetails.rate)
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.get", ms.get)
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.get_rate", ms.getDetails.rate)
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.redeliver", ms.redeliver)
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.redeliver_rate", ms.redeliverDetails.rate)
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.publish", ms.publish.get(0))
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.publish_rate", (
          if ms.publishDetails.isSome(): ms.publishDetails.get().rate
          else: 0.0
        ))
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.deliver_noack", ms.deliverNoAck)
        self.statsDM.gauge("rabbitmq." & overview.node & ".messages.deliver_noack_rate", ms.deliverNoAckDetails.rate)
        
      for node in nodes:
        self.statsDM.gauge("rabbitmq." & node.name & ".mem_used", node.memUsed)
        self.statsDM.gauge("rabbitmq." & node.name & ".fd_used", node.fdUsed)
        self.statsDM.gauge("rabbitmq." & node.name & ".sockets_used", node.socketsUsed)
        self.statsDM.gauge("rabbitmq." & node.name & ".disk_free", node.diskFree)
    except Exception as e:
      echo "Error sending to statsd: ", e.msg
  except Exception as e:
    echo "Error getting from rabbitmq ", e.msg


proc initSelf(cfg: AMQPStatsdConfig): Self =
  result.config = cfg
  result.statsM = newAMQPStats(cfg.rmqURL, cfg.rmqUser, cfg.rmqPasswd)
  result.statsDM = newStatsDClient(cfg.statsdHost, cfg.statsdPort)


proc main(cfg: AMQPStatsdConfig) =
  self = initSelf(cfg)
  var timeout = 0
  while running:
    sleep(SLEEP_TIME)
    timeout += SLEEP_TIME
    timeout = timeout.mod(self.config.updateInterval)
    if timeout == 0:
      onTimerEvent()


when isMainModule:
  let cfg = readConfig()
  echo("Starting application")
  addExitProc(atExit)
  setControlCHook(atExit)
  main(cfg)
