
{-# LANGUAGE PatternGuards #-}

module Seri.Inline (inline) where


import System.IO.Unsafe

import Control.Monad
import Data.IORef
import qualified Data.Map as Map

import Seri.Type
import Seri.Sig
import Seri.Failable
import Seri.Name
import Seri.Exp
import Seri.Dec
import Seri.ExpH
import Seri.Prim

-- | Inline all variables from environment into the given expression.
inline :: Env -> [Prim] -> Exp -> ExpH
inline env prims =
  let {-# NOINLINE cache #-}
      cache :: IORef (Map.Map Sig (Maybe ExpH))
      cache = unsafePerformIO (newIORef Map.empty)

      priml :: Sig -> Maybe ExpH 
      priml = lookupPrim prims

      lookupIO :: Sig -> IO (Maybe ExpH)
      lookupIO s@(Sig n ct) = do
         m <- readIORef cache
         case Map.lookup s m of
            Just v -> return v
            Nothing -> do
              let inprims = priml s
                  inenv = attemptM $ do
                         (pt, ve) <- lookupVar env s
                         return $ inline' (assignments pt ct) [] ve
                  x = mplus inprims inenv
                
              modifyIORef cache (Map.insert s x)
              return x

      lookupPure :: Sig -> Maybe ExpH
      lookupPure s = unsafePerformIO (lookupIO s)

      inline' :: [(Name, Type)] -> [(Sig, ExpH)] -> Exp -> ExpH
      inline' tm m (LitE l) = LitEH l
      inline' tm m (ConE s) = conEH (assign tm s)
      inline' tm m (VarE s) | Just v <- lookup s m = v
      inline' tm m (VarE s) | Just v <- lookupPure (assign tm s) = v
      inline' tm m (VarE s) = VarEH (assign tm s)
      inline' tm m (AppE f x) = appEH (inline' tm m f) (inline' tm m x)
      inline' tm m (LamE s b) = lamEH (assign tm s) (assign tm $ typeof b) $ \x -> inline' tm ((s, x):m) b
      inline' tm m (CaseE x k y n) = caseEH (inline' tm m x) (assign tm k) (inline' tm m y) (inline' tm m n)
  in inline' [] []


