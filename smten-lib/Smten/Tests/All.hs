
{-# LANGUAGE NoImplicitPrelude, RebindableSyntax #-}
module Smten.Tests.All (main) where

import Smten.Prelude
import Smten.Tests.Test
import qualified Smten.Tests.Basic
import qualified Smten.Tests.SMT.Core
import qualified Smten.Tests.SMT.Datatype

main :: IO ()
main = do
  test "Dummy" True
  Smten.Tests.Basic.tests
  Smten.Tests.SMT.Core.tests
  Smten.Tests.SMT.Datatype.tests
  putStrLn "ALL PASSED"

