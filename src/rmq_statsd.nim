import std/[exitprocs, options, os]
import amqpstats, simplestatsdclient
import private/config
import amqpstats/types


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

var overview: Overview

proc onTimerEvent() =
  try:
    overview = self.statsM.overview()
    
    try:
      let overviewNode = "rabbitmq." & overview.node
      self.statsDM.gauge(overviewNode & ".channels", overview.objectTotals.channels)
      self.statsDM.gauge(overviewNode & ".queues", overview.objectTotals.queues)
      self.statsDM.gauge(overviewNode & ".connections", overview.objectTotals.connections)
      self.statsDM.gauge(overviewNode & ".consumers", overview.objectTotals.consumers)
      self.statsDM.gauge(overviewNode & ".exchanges", overview.objectTotals.exchanges)

      if overview.enableQueueTotals:
        self.statsDM.gauge(overviewNode & ".messages.messages", overview.queueTotals.messages.get(0))
        self.statsDM.gauge(overviewNode & ".messages.ready", overview.queueTotals.messagesReady.get(0))
        self.statsDM.gauge(overviewNode & ".messages.unack", overview.queueTotals.messagesUnacknowledged.get(0))
      else:
        var messages: int = 0
        var messagesReady: int = 0
        var messagesUnack: int = 0
        for queue in self.statsM.queuesIt:
          messages.inc(queue.messages.get(0))
          messagesReady.inc(queue.messagesReady.get(0))
          messagesUnack.inc(queue.messagesUnacknowledged.get(0))
        self.statsDM.gauge(overviewNode & ".messages.messages", messages)
        self.statsDM.gauge(overviewNode & ".messages.ready", messagesReady)
        self.statsDM.gauge(overviewNode & ".messages.unack", messagesUnack)

      if overview.messageStats.isSome:
        let ms = overview.messageStats.get
        self.statsDM.gauge(overviewNode & ".messages.ack", ms.ack.get(0))
        self.statsDM.gauge(overviewNode & ".messages.ack_rate", (
          if ms.ackDetails.isSome(): ms.ackDetails.get().rate
          else: 0.0
        ))
        self.statsDM.gauge(overviewNode & ".messages.deliver", ms.deliver.get(0))
        self.statsDM.gauge(overviewNode & ".messages.deliver_rate", 
        (
          if ms.deliverDetails.isSome(): ms.deliverDetails.get().rate
          else: 0.0
        ))
        self.statsDM.gauge(overviewNode & ".messages.get", ms.get.get(0))
        self.statsDM.gauge(overviewNode & ".messages.get_rate", 
        (
          if ms.getDetails.isSome(): ms.getDetails.get().rate
          else: 0.0
        ))
        self.statsDM.gauge(overviewNode & ".messages.redeliver", ms.redeliver.get(0))
        self.statsDM.gauge(overviewNode & ".messages.redeliver_rate", 
        (
          if ms.redeliverDetails.isSome(): ms.redeliverDetails.get().rate
          else: 0.0
        ))
        self.statsDM.gauge(overviewNode & ".messages.publish", ms.publish.get(0))
        self.statsDM.gauge(overviewNode & ".messages.publish_rate", (
          if ms.publishDetails.isSome(): ms.publishDetails.get().rate
          else: 0.0
        ))
        self.statsDM.gauge(overviewNode & ".messages.deliver_noack", ms.deliverNoAck.get(0))
        self.statsDM.gauge(overviewNode & ".messages.deliver_noack_rate", 
        (
          if ms.deliverNoAckDetails.isSome(): ms.deliverNoAckDetails.get().rate
          else: 0.0
        ))
        
      for node in self.statsM.nodesIt:
        let rmqNode = "rabbitmq." & node.name
        self.statsDM.gauge(rmqNode & ".mem_used", node.memUsed)
        self.statsDM.gauge(rmqNode & ".fd_used", node.fdUsed)
        self.statsDM.gauge(rmqNode & ".sockets_used", node.socketsUsed)
        self.statsDM.gauge(rmqNode & ".disk_free", node.diskFree)
      self.statsDM.flush()
    except Exception as e:
      echo "Error sending to statsd: ", e.msg
  except Exception as e:
    echo "Error getting from rabbitmq ", e.msg


proc initSelf(cfg: AMQPStatsdConfig): Self =
  result.config = cfg
  result.statsM = newAMQPStats(cfg.rmqURL, cfg.rmqUser, cfg.rmqPasswd)
  result.statsDM = newStatsDClient(cfg.statsdHost, cfg.statsdPort, buffered=true)


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
