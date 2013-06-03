
module Smten.CodeGen.Type(
    typeCG, classCG, topSigCG, contextCG,
   ) where

import qualified Language.Haskell.TH.Syntax as H

import Smten.Name
import Smten.Type
import Smten.Dec
import Smten.Ppr
import Smten.CodeGen.CG
import Smten.CodeGen.Name

typeCG :: Type -> CG H.Type
typeCG t =
  case t of
    ConT n _
     | n == arrowN -> return H.ArrowT
     | otherwise -> return $ H.ConT (qtynameCG n)
    AppT a b -> do
       a' <- typeCG a
       b' <- typeCG b
       return $ H.AppT a' b'
    VarT n _ -> return $ H.VarT (nameCG n)
    _ -> error $ "TODO: typeCG: " ++ pretty t

classCG :: Class -> CG H.Pred
classCG (Class n tys) = do
    tys' <- mapM typeCG tys
    return $ H.ClassP (qtynameCG n) tys'

topSigCG :: TopSig -> CG H.Dec
topSigCG (TopSig nm ctx t) = do
    t' <- typeCG t
    (tyvs, ctx') <- contextCG t ctx
    return $ H.SigD (nameCG nm) (H.ForallT tyvs ctx' t')

contextCG :: (VarTs a) => a -> Context -> CG ([H.TyVarBndr], [H.Pred])
contextCG x ctx = do 
    tyvnmsbound <- asks cg_tyvars
    ctx' <- mapM classCG ctx
    let tyvnmsall = varTs x
        tyvnmslocal = filter (flip notElem tyvnmsbound . fst) tyvnmsall
        tyvs = map (H.PlainTV . nameCG . fst) tyvnmslocal
        shsctx = concatMap smtenhsCG tyvnmslocal
    return (tyvs, shsctx ++ ctx')

knum :: Kind -> Integer
knum (ArrowK a b) = 1 + knum b
knum _ = 0

smtenhsCG :: (Name, Kind) -> [H.Pred]
smtenhsCG (n, k) = [H.ClassP (H.mkName $ "Smten.SmtenHS" ++ show (knum k)) [H.VarT $ nameCG n]]

