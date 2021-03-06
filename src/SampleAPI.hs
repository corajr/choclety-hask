{-| Exemplifies the basic use of 'LinksFor' and how to generate a graph for an API.
-}

{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeOperators   #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
module SampleAPI where

import Data.Aeson
import Data.Typeable
import Data.Aeson.TH
import Data.DeriveTH
import Network.Wai
import Network.Wai.Handler.Warp
import Network.Wai.Logger
import Test.QuickCheck
import Control.Monad.Trans (liftIO)
import Servant.StateGraph.Graph
import Servant
import Servant.API.TypeLevel

-- * Domain types

data Product = Product
  { productId :: Int
  , productName :: String
  , productPrice :: Float
  } deriving (Eq, Show, Typeable)

$(deriveJSON defaultOptions ''Product)

derive makeArbitrary ''Product

data Category = Category
  { categoryId :: Int
  , categoryName :: String
  , categoryProducts :: [Product]
  } deriving (Eq, Show, Typeable)

$(deriveJSON defaultOptions ''Category)

derive makeArbitrary ''Category

data Cart = Cart
  { cartProducts :: [Product]
  } deriving (Eq, Show, Typeable)

$(deriveJSON defaultOptions ''Cart)

derive makeArbitrary ''Cart

data Vendor = Vendor
  { vendorId :: Int
  , vendorProducts :: [Product]
  } deriving (Eq, Show, Typeable)

$(deriveJSON defaultOptions ''Vendor)

derive makeArbitrary ''Vendor

data Invoice = Invoice
  { invoiceId :: Int
  , invoiceProducts :: [Product]
  , invoiceTotal :: Float
  } deriving (Eq, Show, Typeable)

$(deriveJSON defaultOptions ''Invoice)

derive makeArbitrary ''Invoice

data ErrorState = ErrorState
  { message :: String
  } deriving (Eq, Show, Typeable)

$(deriveJSON defaultOptions ''ErrorState)

derive makeArbitrary ''ErrorState

arb :: (Arbitrary a) => Handler a
arb = liftIO (generate arbitrary)

newtype Homepage = Homepage { homeData :: ([Category], [Vendor]) }

$(deriveJSON defaultOptions ''Homepage)

derive makeArbitrary ''Homepage

-- * API types

type HomeRoute = Get '[JSON] Homepage

type IndexRoute a = Get '[JSON] [a]
type ShowRoute a = Capture "id" Int :> Get '[JSON] a

type CategoryIndex = "categories" :> IndexRoute Category
type CategoryShow = "categories" :> ShowRoute Category
type VendorIndex = "vendors" :> IndexRoute Vendor
type VendorShow = "vendors" :> ShowRoute Vendor

type ProductShow = "products" :> ShowRoute Product
type AddToCart = "products" :> Capture "id" Int :> "add" :> Post '[JSON] Cart

type Purchase = "cart" :> "buy" :> Post '[JSON] Invoice

type ErrorRoute = Get '[JSON] ErrorState

type Shoppe1 =
  HomeRoute
  :<|> CategoryIndex
  :<|> CategoryShow
  :<|> VendorIndex
  :<|> VendorShow
  :<|> ProductShow
  :<|> AddToCart
  :<|> Purchase
  :<|> ErrorRoute

instance LinksFor Shoppe1 where
  linksFor api =
    [ linkFor api (edgeFrom :: Root :=> HomeRoute) NormalNode
    , linkFor api (edgeFrom :: Root :=> ErrorRoute) ErrorNode
    , linkFor api (edgeFrom :: ErrorRoute :=> HomeRoute) NormalNode
    , linkFor api (edgeFrom :: HomeRoute :=> CategoryIndex) NormalNode
    , linkFor api (edgeFrom :: HomeRoute :=> VendorIndex) NormalNode
    , linkFor api (edgeFrom :: CategoryIndex :=> CategoryShow) NormalNode
    , linkFor api (edgeFrom :: VendorIndex :=> VendorShow) NormalNode
    , linkFor api (edgeFrom :: VendorShow :=> ProductShow) NormalNode
    , linkFor api (edgeFrom :: CategoryShow :=> ProductShow) NormalNode
    , linkFor api (edgeFrom :: ProductShow :=> AddToCart) NormalNode
    , linkFor api (edgeFrom :: AddToCart :=> Purchase) TargetNode
    ]

-- | Turn the API type proxy into an 'ApiGraph'.
apiGraph :: ApiGraph
apiGraph = graph api

-- | Serve the API.
startApp :: IO ()
startApp =
    withStdoutLogger $ \aplogger -> do
        let settings = setPort 8080 $ setLogger aplogger defaultSettings
        runSettings settings app

-- | The API as a WAI 'Application'.
app :: Application
app = serve api server

-- | API type proxy.
api :: Proxy Shoppe1
api = Proxy

-- | A fake server (generates arbitrary data).
server :: Server Shoppe1
server =
  arb -- HomeRoute
  :<|> arb -- CategoryIndex
  :<|> const arb  -- CategoryShow
  :<|> arb -- VendorIndex
  :<|> const arb -- VendorShow
  :<|> const arb -- "products" :> ShowRoute Product
  :<|> const arb -- "products" :> Capture "id" Int :> "add"
  :<|> arb -- "cart" :> "buy" :> Post '[JSON] Invoice
  :<|> arb
