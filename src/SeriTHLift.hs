
{-# LANGUAGE TemplateHaskell #-}

module SeriTHLift ()
    where

import Language.Haskell.TH.Syntax (Lift(..))

import Seri

instance Lift Type where
    lift IntegerT = [e| IntegerT |]
    lift (ArrowT a b) = [e| ArrowT a b |]
    lift UnknownT = [e| UnknownT |]

instance Lift Exp where
    lift (IntegerE x) = [e| IntegerE x |]
    lift (AddE a b) = [e| AddE a b |]
    lift (MulE a b) = [e| MulE a b |]
    lift (AppE t a b) = [e| AppE t a b |]
    lift (LamE t n e) = [e| LamE t n e |]
    lift (VarE t n) = [e| VarE t n |]

