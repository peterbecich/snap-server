module Snap.Internal.Http.Server.TimeoutManager.Tests
  ( tests ) where

import           Control.Concurrent
import           Data.IORef
import           Data.Maybe
import           System.PosixCompat.Time
import           System.Timeout
import           Test.Framework
import           Test.Framework.Providers.HUnit
import           Test.HUnit                               hiding (Test, path)

import qualified Snap.Internal.Http.Server.TimeoutManager as TM

tests :: [Test]
tests = [ testOneTimeout
        , testOneTimeoutAfterInactivity
        , testCancel
        , testTickle ]


testOneTimeout :: Test
testOneTimeout = testCase "timeout/oneTimeout" $ do
    mgr <- TM.initialize 1 epochTime
    oneTimeout mgr


testOneTimeoutAfterInactivity :: Test
testOneTimeoutAfterInactivity =
    testCase "timeout/oneTimeoutAfterInactivity" $ do
        mgr <- TM.initialize 1 epochTime
        threadDelay $ 3 * seconds
        oneTimeout mgr

oneTimeout :: TM.TimeoutManager -> IO ()
oneTimeout mgr = do
    mv  <- newEmptyMVar
    _   <- TM.register (putMVar mv ()) mgr
    m   <- timeout (3*seconds) $ takeMVar mv
    assertBool "timeout fired" $ isJust m
    TM.stop mgr


testTickle :: Test
testTickle = testCase "timeout/tickle" $ do
    mgr <- TM.initialize 5 epochTime
    ref <- newIORef (0 :: Int)
    h <- TM.register (writeIORef ref 1) mgr
    threadDelay $ 1 * seconds
    b0 <- readIORef ref
    assertEqual "b0" 0 b0
    TM.tickle h 3
    threadDelay $ 1 * seconds
    b1 <- readIORef ref
    assertEqual "b1" 0 b1
    threadDelay $ 5 * seconds
    b2 <- readIORef ref
    assertEqual "b2" 1 b2
    TM.stop mgr


testCancel :: Test
testCancel = testCase "timeout/cancel" $ do
    mgr <- TM.initialize 3 epochTime
    ref <- newIORef (0 :: Int)
    h <- TM.register (writeIORef ref 1) mgr
    threadDelay $ 1 * seconds
    readIORef ref >>= assertEqual "b0" 0
    TM.cancel h
    TM.tickle h 10              -- make sure tickle ignores cancelled times
    threadDelay $ 2 * seconds
    readIORef ref >>= assertEqual "b1" 1
    threadDelay $ 2 * seconds
    h' <- TM.register (writeIORef ref 2) mgr
    _ <- TM.register (return ()) mgr
    TM.set h' 1
    threadDelay $ 2 * seconds
    readIORef ref >>= assertEqual "b2" 2
    _   <- TM.register (writeIORef ref 3) mgr
    h'' <- TM.register (return ()) mgr
    TM.cancel h''
    TM.stop mgr
    threadDelay $ 1 * seconds
    readIORef ref >>= assertEqual "b3" 3



seconds :: Int
seconds = (10::Int) ^ (6::Int)
