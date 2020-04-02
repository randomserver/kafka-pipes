{-# LANGUAGE LambdaCase #-}
module Kafka.Pipes (kafkaSink) where

import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Catch (bracket, MonadMask)
import Data.Functor ((<&>))
import Pipes
import Pipes.Safe (MonadSafe)
import Kafka.Producer
import Kafka.Consumer (Offset)

sendMessageSync :: MonadIO m
                => KafkaProducer
                -> ProducerRecord
                -> m (Either KafkaError Offset)
sendMessageSync producer record = liftIO $ do
  -- Create an empty MVar:
  var <- newEmptyMVar

  -- Produce the message and use the callback to put the delivery report in the
  -- MVar:
  res <- produceMessage' producer record (putMVar var)

  case res of
    Left (ImmediateError err) ->
      pure (Left err)
    Right () -> do
      -- Flush producer queue to make sure you don't get stuck waiting for the
      -- message to send:
      flushProducer producer

      -- Wait for the message's delivery report and map accordingly:
      takeMVar var <&> \case
        DeliverySuccess _ offset -> Right offset
        DeliveryFailure _ err    -> Left err
        NoMessageError err       -> Left err

kafkaSink :: (MonadIO m, MonadMask m) 
          => ProducerProperties
          -> Consumer ProducerRecord m ()
kafkaSink props = void $ bracket connect release publish
  where
    connect = liftIO $ newProducer props
    
    release (Left err)       = return ()
    release (Right producer) = liftIO $ closeProducer producer

    publish (Left err)       = return $ Left err
    publish (Right producer) = do
      r <- await
      res <- liftIO $ sendMessageSync producer r
      case res of
        Left err -> return $ Left err
        Right _  -> publish $ Right producer