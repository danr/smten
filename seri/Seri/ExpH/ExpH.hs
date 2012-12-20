
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE PatternGuards #-}

-- | HOAS form for Seri Expressions, geared towards high performance
-- elaboration.
module Seri.ExpH.ExpH (
    ExpH(..), ID, identify, getid,
    ) where

import System.IO.Unsafe
import Data.IORef
import Data.Typeable

import Seri.Lit
import Seri.Name
import Seri.Type
import Seri.Sig

type ID = Integer

data ExpH = LitEH Lit
          | ConEH ID Name Type [ExpH]
                -- ^ type is for fully applied constructor.
          | VarEH Sig
          | PrimEH ID Name Type ([ExpH] -> ExpH) [ExpH]
                -- ^ type is for fully applied primitive.
         
          -- | AppEH f x i
          --  f - the function
          --  x - the argument
          | AppEH ID ExpH ExpH

          -- | LamEH s t f:
          --    s - name and type of the function argument. 
          --        The name is for debugging purposes only.
          --    t - the return type of the function
          --    f - the haskell representation of the function.
          | LamEH ID Sig Type (ExpH -> ExpH)

          | CaseEH ID ExpH Sig ExpH ExpH
            -- ^ case e1 of
            --      k -> e2
            --      _ -> e3
            -- Note: if k is a constructor of type (a -> b -> c -> K),
            -- Then e2 should have type: (a -> b -> c -> V),
            -- And  e1 should have type: V
            --  Where V is the type of the case expression.
          | ErrorEH Type String -- ^ type is type of expression.
    deriving(Typeable)

-- Call the given function with a globally unique identifier.
identify :: (ID -> a) -> a
identify f = 
  let {-# NOINLINE idstore #-}
      idstore :: IORef ID
      idstore = unsafePerformIO (newIORef 0)

      identifyIO :: (ID -> a) -> IO a
      identifyIO f = do
        x <- readIORef idstore
        writeIORef idstore (x + 1)
        return (f x)
  in unsafePerformIO $ identifyIO f

-- Return the ID of the given complex expression, or None if the
-- expression is simple
getid :: ExpH -> Maybe ID
getid e
  | ConEH _ _ _ [] <- e = Nothing
  | ConEH x _ _ _ <- e = Just x
  | PrimEH x _ _ _ _ <- e = Just x
  | AppEH x _ _ <- e = Just x
  | LamEH x _ _ _ <- e = Just x
  | CaseEH x _ _ _ _ <- e = Just x
  | otherwise = Nothing
