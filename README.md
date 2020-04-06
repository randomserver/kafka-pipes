# kafka-pipes

![Haskell CI](https://github.com/kaffepanna/kafka-pipes/workflows/Haskell%20CI/badge.svg)

Simple kafka source/sink in the [Pipes](https://hackage.haskell.org/package/pipes) ecosystem.
Based on the [hw-kafka-client](https://github.com/haskell-works/hw-kafka-client) library from [haskell works]()

## Example consuming kafka records

```haskell
import Control.Exception (bracket)
import Data.Monoid ((<>))
import Kafka
import Kafka.Consumer
import Kafka.Pipes.Source

import Pipes
import qualified Pipes.Prelude as PP

-- Global consumer properties
consumerProps :: ConsumerProperties
consumerProps = brokersList [BrokerAddress "localhost:9092"]
             <> groupId (ConsumerGroupId "test_group")
             <> noAutoCommit
             <> logLevel KafkaLogInfo

-- Subscription to topics
consumerSub :: Subscription
consumerSub = topics [TopicName "topic.name"]
           <> offsetReset Earliest

topicPrinter = source >-> value >-> PP.show
    where source = kafkaSource consumerProps consumerSub
          value (ConsumerRecord topic partition offset timestamp key value) = yield value
```