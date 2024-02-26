import std/[asyncdispatch, exitprocs, options]
import amqpstats, simplestatsdclient
import private/config


const SLEEP_TIME = 500


type
  Self = object
    config: AMQPStatsdConfig
    statsM: AMQPStatsAsync
    statsDM: AsyncStatsDClient


var running: bool = true
var self {.noinit.}: Self


proc atExit() {.noconv.} =
  running = false
  echo "Stopping application"


proc onTimerEvent() {.async.} =
  try:
    let overview = await self.statsM.overview()
    let nodes = await self.statsM.nodes()
    try:
      await self.statsDM.gauge("rabbitmq." & overview.node & ".channels", overview.objectTotals.channels)
      await self.statsDM.gauge("rabbitmq." & overview.node & ".queues", overview.objectTotals.queues)
      await self.statsDM.gauge("rabbitmq." & overview.node & ".connections", overview.objectTotals.connections)
      await self.statsDM.gauge("rabbitmq." & overview.node & ".consumers", overview.objectTotals.consumers)
      await self.statsDM.gauge("rabbitmq." & overview.node & ".exchanges", overview.objectTotals.exchanges)

      if overview.enableQueueTotals:
        await self.statsDM.gauge("rabbitmq." & overview.node & ".messages.messages", overview.queueTotals.messages.get(0))
        await self.statsDM.gauge("rabbitmq." & overview.node & ".messages.ready", overview.queueTotals.messagesReady.get(0))
        await self.statsDM.gauge("rabbitmq." & overview.node & ".messages.unack", overview.queueTotals.messagesUnacknowledged.get(0))

      if overview.messageStats.isSome:
        let ms = overview.messageStats.get
        await self.statsDM.gauge("rabbitmq." & overview.node & ".messages.ack", ms.ack)
        await self.statsDM.gauge("rabbitmq." & overview.node & ".messages.ack_rate", ms.ackDetails.rate)
        await self.statsDM.gauge("rabbitmq." & overview.node & ".messages.deliver", ms.deliver)
        await self.statsDM.gauge("rabbitmq." & overview.node & ".messages.deliver_rate", ms.deliverDetails.rate)
        await self.statsDM.gauge("rabbitmq." & overview.node & ".messages.get", ms.get)
        await self.statsDM.gauge("rabbitmq." & overview.node & ".messages.get_rate", ms.getDetails.rate)
        await self.statsDM.gauge("rabbitmq." & overview.node & ".messages.redeliver", ms.redeliver)
        await self.statsDM.gauge("rabbitmq." & overview.node & ".messages.redeliver_rate", ms.redeliverDetails.rate)
        
        await self.statsDM.gauge("rabbitmq." & overview.node & ".messages.publish", ms.publish.get(0))
        await self.statsDM.gauge("rabbitmq." & overview.node & ".messages.publish_rate", (
          if ms.publishDetails.isSome(): ms.publishDetails.get().rate
          else: 0.0
        ))
        

      for node in nodes:
        await self.statsDM.gauge("rabbitmq." & node.name & ".mem_used", node.memUsed)
        await self.statsDM.gauge("rabbitmq." & node.name & ".fd_used", node.fdUsed)
        await self.statsDM.gauge("rabbitmq." & node.name & ".sockets_used", node.socketsUsed)
        await self.statsDM.gauge("rabbitmq." & node.name & ".disk_free", node.diskFree)
    except Exception as e:
      echo "Error sending to statsd: ", e.msg
  except Exception as e:
    echo "Error getting from rabbitmq ", e.msg


proc timer() {.async.} =
  var timeout = 0
  while running:
    await sleepAsync(SLEEP_TIME)
    timeout += SLEEP_TIME
    timeout = timeout.mod(self.config.updateInterval)
    if timeout == 0:
      await onTimerEvent()


proc initSelf(cfg: AMQPStatsdConfig): Self =
  result.config = cfg
  result.statsM = newAMQPStatsAsync(cfg.rmqURL, cfg.rmqUser, cfg.rmqPasswd)
  result.statsDM = newAsyncStatsDClient(cfg.statsdHost, cfg.statsdPort)


proc main(cfg: AMQPStatsdConfig) {.async.} =
  self = initSelf(cfg)
  let timerFuture {.used.} = timer()
  while running:
    await asyncdispatch.sleepAsync(100)
  await timerFuture


when isMainModule:
  let cfg = readConfig()
  echo("Starting application")
  addExitProc(atExit)
  setControlCHook(atExit)
  waitFor(main(cfg))
