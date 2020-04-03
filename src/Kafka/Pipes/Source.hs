module Kafka.Pipes.Source where

import Control.Monad.IO.Class (liftIO, MonadIO)
import Control.Monad.Catch (bracket, MonadMask)
import Pipes
import Pipes.Safe (MonadSafe)
import Kafka.Consumer
import Data.ByteString (ByteString)

kafkaSource :: (MonadIO m, MonadMask m)
            => ConsumerProperties
            -> Subscription
            -> Producer (ConsumerRecord (Maybe ByteString) (Maybe ByteString)) m ()
kafkaSource props sub = void $ bracket mkConsumer clConsumer consumerSub
  where mkConsumer = liftIO $ newConsumer props sub
        clConsumer (Left err)       = return ()
        clConsumer (Right consumer) = liftIO $ void $ closeConsumer consumer
        consumerSub (Left err)       = return $ Left err
        consumerSub (Right consumer) = do
          mMsg <- liftIO $ pollMessage consumer (Timeout 1000)
          case mMsg of
            Left err    -> return $ Left err
            Right msg -> do 
              yield msg
              mErr <- liftIO $ commitAllOffsets OffsetCommit consumer
              case mErr of
                Just err -> return $ Left err
                Nothing  -> consumerSub $ Right consumer

