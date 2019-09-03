{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import Control.DeepSeq (NFData(..))
import Criterion.Main as Criterion
import Control.Monad (replicateM_, void)
import Data.Int
import Data.Singletons (SomeSing(..))
import qualified Data.Text.Foreign as Text
import Data.Word
import qualified Foreign.Concurrent as Concurrent
import qualified Foreign.ForeignPtr as ForeignPtr
import Foreign.JNI
import Foreign.Marshal.Alloc (mallocBytes, finalizerFree, free)
import Foreign.Marshal.Array (callocArray, mallocArray)
import Foreign.Ptr (Ptr)
import Language.Java

newtype Box a = Box { unBox :: a }

-- Not much sense in deepseq'ing foreign pointers. But needed for call to 'env'
-- below.
instance NFData (Box a) where rnf (Box a) = seq a ()

jabs :: Int32 -> IO Int32
jabs x = callStatic "java.lang.Math" "abs" [coerce x]

jniAbs :: JClass -> JMethodID -> Int32 -> IO Int32
jniAbs klass method x = callStaticIntMethod klass method [coerce x]

intValue :: Int32 -> IO Int32
intValue x = do
    jx <- reflect x
    call jx "intValue" []

compareTo :: Int32 -> Int32 -> IO Int32
compareTo x y = do
    jx <- reflect x
    jy <- reflect y
    call jx "compareTo" [coerce jy]

incrHaskell :: Int32 -> IO Int32
incrHaskell x = return (x + 1)

foreign import ccall unsafe getpid :: IO Int

benchCalls :: Benchmark
benchCalls =
    env ini $ \ ~(Box klass, method) ->
      bgroup "Calls"
      [ bgroup "Java calls"
        [ bench "static method call: unboxed single arg / unboxed return" $ nfIO $ jabs 1
        , bench "jni static method call: unboxed single arg / unboxed return" $ nfIO $ jniAbs klass method 1
        , bench "method call: no args / unboxed return" $ nfIO $ intValue 1
        , bench "method call: boxed single arg / unboxed return" $ nfIO $ compareTo 1 1
        ]
      , bgroup "Haskell calls"
        [ bench "incr haskell" $ nfIO $ incrHaskell 1
        , bench "ffi haskell" $ nfIO $ getpid
        ]
      ]
  where
    ini = do
      klass <- findClass (referenceTypeName (SClass "java/lang/Math"))
      method <- getStaticMethodID klass "abs" (methodSignature [SomeSing (sing :: Sing ('Prim "int"))] (SPrim "int"))
      return (Box klass, method)

benchRefs :: Benchmark
benchRefs =
    env (Box <$> new []) $ \ ~(Box (jobj :: JObject)) ->
    bgroup "References"
    [ bench "local reference" $ nfIO $ do
        _ <- newLocalRef jobj
        return ()
    , bench "global reference" $ nfIO $ do
        _ <- newGlobalRef jobj
        return ()
    ,  bench "global reference (no finalizer)" $ nfIO $ do
        _ <- newGlobalRefNonFinalized jobj
        return ()
    , bench "Foreign.Concurrent.newForeignPtr" $ nfIO $ do
        _ <- Concurrent.newForeignPtr (unsafeObjectToPtr jobj) (return ())
        return ()
    , bench "Foreign.ForeignPtr.newForeignPtr" $ nfIO $ do
        -- Approximate cost of malloc: 50ns. Ideally would move out of benchmark
        -- but finalizer not idempotent.
        ptr <- mallocBytes 4
        _ <- ForeignPtr.newForeignPtr finalizerFree ptr
        return ()
    , bench "local frame / 1 reference" $ nfIO $ do
        pushLocalFrame 30
        _ <- newLocalRef jobj
        _ <- popLocalFrame jnull
        return ()
    , bench "delete 1 local ref" $ nfIO $
        newLocalRef jobj >>= deleteLocalRef
    , bench "local frame / 30 references" $ nfIO $ do
        pushLocalFrame 30
        replicateM_ 30 $ newLocalRef jobj
        _ <- popLocalFrame jnull
        return ()
    , bench "delete 30 local refs" $ nfIO $
        replicateM_ 30 $ newLocalRef jobj >>= deleteLocalRef
    ]

benchNew :: Benchmark
benchNew =
    bgroup "new"
    [ bench "Integer" $
      perBatchEnvWithCleanup
        (pushLocalFrame . (2*) . fromIntegral)
        (\_ _ -> void (popLocalFrame jnull)) $
        \() -> do
          _ <- new [JInt 2] :: IO (J ('Class "java.lang.Integer"))
          return ()
    , envWithCleanup allocTextPtr freeTextPtr $ \ ~(Box (ptr, len)) ->
      bench "newString" $
      perBatchEnvWithCleanup
        (pushLocalFrame . (2*) . fromIntegral)
        (\_ _ -> void (popLocalFrame jnull)) $
        \() ->
          void $ newString ptr (fromIntegral len)
    , envWithCleanup allocTextPtr freeTextPtr $ \ ~(Box (ptr, len)) ->
      bench "newArray" $
      perBatchEnvWithCleanup
        (pushLocalFrame . (2*) . fromIntegral)
        (\_ _ -> void (popLocalFrame jnull)) $
        \() ->
          void $ newByteArray (fromIntegral len)
    ]
  where
    allocTextPtr = do
      let len = 128
      dst <- callocArray len
      return $ Box (dst, fromIntegral len)
    freeTextPtr (Box (p, _)) = free p

main :: IO ()
main = withJVM [] $ do
    Criterion.defaultMain [benchCalls, benchRefs, benchNew]
