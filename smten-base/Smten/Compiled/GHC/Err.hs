
{-# LANGUAGE PatternGuards #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude #-}
module Smten.Compiled.GHC.Err (
    error, divZeroError, overflowError,
 )  where

import Smten.Compiled.Smten.Smten.Base
import GHC.Err (divZeroError, overflowError)

