
module Seri.IR (
    Name, Type(..), Primitive(..), Exp(..), Dec(..),
    lookupvar, nubdecl
    ) where

import Data.List(nub)

import Seri.Ppr

type Name = String

data Type = ConT Name
          | ArrowT
          | UnitT
          | AppT Type Type
          | VarT Name
      deriving(Eq, Show)

data Primitive = AddP
               | SubP
               | MulP
               | LtP
               | TrueP
               | FalseP
               | FixP
               | UnitP
      deriving(Eq, Show)

data Exp = IntegerE Integer
         | PrimE Type Primitive
         | IfE Type Exp Exp Exp
         | AppE Type Exp Exp
         | LamE Type Name Exp
         | VarE Type Name
     deriving(Eq, Show)

data Dec = ValD Name Type Exp
     deriving(Eq, Show)

instance Ppr Type where
    ppr (ConT nm) = text nm
    ppr ArrowT = text "->"
    ppr (AppT a b) = parens $ ppr a <+> ppr b
    ppr (VarT n) = text n
    ppr UnitT = text "Unit"

instance Ppr Primitive where
    ppr AddP = text "+"
    ppr SubP = text "-"
    ppr MulP = text "*"
    ppr LtP = text "<"
    ppr TrueP = text "True"
    ppr FalseP = text "False"
    ppr FixP = text "fix"
    ppr UnitP = text "unit"

instance Ppr Exp where
    ppr (IntegerE i) = integer i
    ppr (PrimE _ p) = ppr p
    ppr (IfE _ p a b) = parens $ text "if" <+> ppr p
                        <+> text "then" <+> ppr a
                        <+> text "else" <+> ppr b
    ppr (AppE _ a b) = parens $ ppr a <+> ppr b
    ppr (LamE _ n b) = parens $ text "\\" <> text n <+> text "->" <+> ppr b
    ppr (VarE _ n) = text n

instance Ppr Dec where
    ppr (ValD n t e) = text n <+> text "::" <+> ppr t
                        $+$ text n <+> text "=" <+> ppr e

lookupvar :: Name -> [Dec] -> Maybe Dec
lookupvar x [] = Nothing
lookupvar x (d@(ValD nm _ _):ds) | nm == x = Just d
lookupvar x (d:ds) = lookupvar x ds

-- remove duplicate occurences of a declaration from the list.
nubdecl :: [Dec] -> [Dec]
nubdecl = nub

