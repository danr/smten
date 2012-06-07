
module Seri.Target.Yices.Builtins.Integer (
    integerY
  ) where

import qualified Math.SMT.Yices.Syntax as Y

import Seri.Lambda
import Seri.Target.Yices.Compiler
import Seri.Utils.Ppr
import Seri.Target.Haskell.Builtin

binop :: Exp -> Exp -> (Y.ExpY -> Y.ExpY -> Y.ExpY) -> Compiler -> Maybe ([Y.CmdY], Y.ExpY)
binop a b cop c = do
    (as, a') <- compile_exp c c a
    (bs, b') <- compile_exp c c b
    return (as ++ bs, cop a' b')

yExp :: Compiler -> Exp -> Maybe ([Y.CmdY], Y.ExpY)
yExp c (AppE (AppE (PrimE (Sig "+" _)) a) b) = binop a b (Y.:+:) c
yExp c (AppE (AppE (PrimE (Sig "-" _)) a) b) = binop a b (Y.:-:) c
yExp c (AppE (AppE (PrimE (Sig "<" _)) a) b) = binop a b (Y.:<) c
yExp c (AppE (AppE (PrimE (Sig ">" _)) a) b) = binop a b (Y.:>) c
yExp c (AppE (AppE (PrimE (Sig "==" _)) a) b) = binop a b (Y.:=) c
yExp _ _ = Nothing

yType :: Compiler -> Type -> Maybe Y.TypY
yType _ (ConT "Integer") = Just $ Y.VarT "int"
yType _ _ = Nothing

integerY :: Compiler
integerY = Compiler yExp yType

