
{-# LANGUAGE PatternGuards #-}

module Seri.ExpH.Ppr () where

import Seri.Lit
import Seri.Ppr
import Seri.ExpH.ExpH
import Seri.ExpH.Sugar
import Seri.ExpH.Sugar2

instance Ppr ExpH where
    ppr e | Just v <- de_stringEH e = text (show v)
    ppr (LitEH l) = ppr l
    ppr (ConEH s) = ppr s
    ppr (VarEH s) = ppr s
    ppr (PrimEH s _ xs) = ppr (appsEH (varEH s) xs)
    ppr (AppEH f x) = parens (ppr f) <+> parens (ppr x)
    ppr (LamEH s f) = text "\\" <+> ppr s <+> text "-> ..."
    ppr (CaseEH e1 p e2 e3)
        = text "case" <+> parens (ppr e1) <+> text "of" <+> text "{"
            $+$ nest tabwidth (vcat [
                    ppr p <+> text "->" <+> ppr e2,
                    text "_" <+> text "->" <+> ppr e3
                  ]) $+$ text "}"
    ppr (ErrorEH t s) = text "error" <+> text s

