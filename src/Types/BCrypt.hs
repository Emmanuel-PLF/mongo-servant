--{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
--{-# LANGUAGE QuasiQuotes #-}
--{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module Types.BCrypt (
    BCrypt,
    hashPassword,
    validatePassword,
) where

-- Prelude.
--import           ClassyPrelude        hiding (hash)

-- Local imports.
--import Control.Monad.Except (MonadIO, liftIO)
--import Control.Monad.Reader (MonadReader, ReaderT, asks)
import Crypto.KDF.BCrypt qualified as BC
import Data.Aeson (FromJSON, ToJSON)

--import Data.Text
--import Data.Text.Encoding (decodeUtf8, encodeUtf8)
--import Database.Persist.MongoDB (PersistField)
import Database.Persist.Sql as S
import Database.Persist.TH ()

--import Katip
--   ( KatipContext,
--     Severity (..),
--     logStr,
--     logTM,
--     logMsg
--   )

import Config
import Control.Monad.Logger (logDebugNS)
import Logger ()

--------------------------------------------------------------------------------

-- | Newtype wrapper for passwords hashed using BCrypt.
newtype BCrypt = BCrypt
    { unBCrypt :: Text
    }
    deriving (Eq, Read, PersistField, S.PersistFieldSql, FromJSON, ToJSON, Show)

--------------------------------------------------------------------------------

-- | Produce a hashed output, given some plaintext input.
hashPassword :: MonadIO m => Text -> m BCrypt
hashPassword pass =
    let hash = liftIO $ BC.hashPassword 12 $ encodeUtf8 @Text @ByteString pass
     in BCrypt . decodeUtf8 @Text @ByteString <$> hash

{- | Validate that the plaintext is equivalent to a hashed @BCrypt@, log any
 validation failures.
-}
validatePassword ::
    (MonadIO m) =>
    Text ->
    BCrypt ->
    AppT m Bool
validatePassword pass' hash' = do
    let pass = encodeUtf8 @Text @ByteString pass'
        hash = encodeUtf8 @Text @ByteString . unBCrypt $ hash'
        isValid = BC.validatePasswordEither @ByteString pass hash
    case isValid of
        Left e -> do
            logDebugNS "validate" "error on validation password"
            pure False
        Right v -> pure v
