{-| Type-level functions to turn an API into a HAL API.
-}

{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE PolyKinds             #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeOperators         #-}
{-# LANGUAGE UndecidableInstances  #-}

module Servant.HAL.Server where

import           Data.Proxy              (Proxy (..))
import           Servant.API
import           Servant.HAL
import           Servant.Server.Internal

-- | Transform API type @api@ to a type supporting HAL+JSON.
type family Hyper api where
  Hyper (a :<|> b) = Hyper a :<|> Hyper b
  Hyper (e :> x) = e :> Hyper x
  Hyper (Verb m s ct a) = Verb m s (HALJSON ': ct) a

-- | Transform a 'Proxy api' into 'Proxy (Hyper api)'.
hyper :: Proxy api -> Proxy (Hyper api)
hyper _ = Proxy
