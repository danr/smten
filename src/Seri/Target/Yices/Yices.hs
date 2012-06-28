
module Seri.Target.Yices.Yices (
    YS, ys, YCompiler, runYCompiler, yicesN, yicesE, yicesT, yicesD
    ) where

import qualified Math.SMT.Yices.Syntax as Y

import Control.Monad.State

import Seri.Failable
import Seri.Lambda

runYCompiler :: YCompiler a -> YS -> Failable (a, YS)
runYCompiler = runStateT

ys :: YS
ys = YS [] 1

-- | Convert a seri name to a yices name.
yicesN :: String -> String
yicesN = yicesname

-- | Compile a seri expression to a yices expression.
-- The expression should be monomorphic.
-- Returns also a set of declarations that need to be made before using the
-- expression.
yicesE :: Exp -> YCompiler ([Y.CmdY], Y.ExpY)
yicesE e = do
    e' <- yExp e
    cmds <- gets ys_cmds
    modify $ \ys -> ys { ys_cmds = [] }
    return (cmds, e')

-- | Compile a seri type to a yices type
-- The type should be monomorphic.
yicesT :: Type -> Failable Y.TypY
yicesT = yType

-- | Compile a seri declarations to yices declarations.
-- The declarations should be monomorphic and in dependency order.
yicesD :: Dec -> YCompiler [Y.CmdY]
yicesD d = do
    d' <- yDec d
    cmds <- gets ys_cmds
    modify $ \ys -> ys { ys_cmds = [] }
    return (cmds ++ d')

data YS = YS {
    ys_cmds :: [Y.CmdY],   -- ^ Declarations needed for what was compiled
    ys_errid :: Integer    -- ^ unique id to use for next free error variable
}

type YCompiler = StateT YS Failable

yfail :: String -> YCompiler a
yfail = lift . fail

-- Given the argument type and output type of a free error variable, return
-- the yices name of a newly defined one.
yfreeerr :: Type -> Type -> YCompiler String
yfreeerr it ot = do
    t <- lift $ yType (arrowsT [it, ot])
    id <- gets ys_errid
    let nm = yicesname ("err~" ++ show id)
    let cmd = Y.DEFINE (nm, t) Nothing
    modify $ \ys -> ys { ys_cmds = cmd : ys_cmds ys, ys_errid = id+1 }
    return nm

-- Translate a seri expression to a yices expression
yExp :: Exp -> YCompiler Y.ExpY
yExp (IntegerE x) = return $ Y.LitI x
yExp e@(CaseE _ []) = yfail $ "empty case statement: " ++ pretty e
yExp (CaseE e ms) =
  let -- depat p e
      --    outputs: (predicate, bindings)
      --   predicate - predicates indicating if the 
      --                pattern p matches expression e
      --   bindings - a list of bindings made when p matches e.
      depat :: Pat -> Y.ExpY -> ([Y.ExpY], [((String, Maybe Y.TypY), Y.ExpY)])
      depat (ConP _ n ps) e =
        let (preds, binds) = unzip [depat p (Y.APP (Y.VarE (yicesname n ++ show i)) [e])
                                    | (p, i) <- zip ps [0..]]
            mypred = Y.APP (Y.VarE (yicesname n ++ "?")) [e]
        in (mypred:(concat preds), concat binds)
      depat (VarP (Sig n t)) e =
        let 
        in ([], [((n, attemptM $ yType t), e)])
      depat (IntegerP i) e = ([Y.LitI i Y.:= e], [])
      depat (WildP _) _ = ([], [])

      -- take the AND of a list of predicates in a reasonable way.
      yand :: [Y.ExpY] -> Y.ExpY
      yand [] = Y.VarE "true"
      yand [x] = x
      yand xs = Y.AND xs

      -- dematch e ms
      --    e - the expression being cased on
      --    ms - the remaining matches in the case statement.
      --  outputs - the yices expression implementing the matches.
      dematch :: Y.ExpY -> [Match] -> YCompiler Y.ExpY
      dematch ye [] = do
          errnm <- yfreeerr (typeof e) (typeof (head ms))
          return $ Y.APP (Y.VarE errnm) [ye]
      dematch e ((Match p b):ms) = do
          bms <- dematch e ms
          b' <- yExp b
          let (preds, bindings) = depat p e
          let pred = yand preds
          return $ Y.IF pred (Y.LET bindings b') bms
  in do
      e' <- yExp e
      dematch e' ms
yExp (AppE a b) = do
    a' <- yExp a
    b' <- yExp b
    return $ Y.APP a' [b']
yExp (LamE (Sig n t) e) = do
    e' <- yExp e
    t' <- lift $ yType t
    return $ Y.LAMBDA [(n, t')] e'
yExp (ConE (Sig n _)) = return $ Y.VarE (yicescon n)
yExp (VarE (Sig n _)) = return $ Y.VarE (yicesname n)

-- Yices data constructors don't support partial application, so we wrap them in
-- functions given by the following name.
yicescon :: Name -> Name
yicescon n = yicesname $ "C" ++ n

yType :: Type -> Failable Y.TypY
yType (ConT n) = return $ Y.VarT (yicesname n)
yType (AppT (AppT (ConT "->") a) b) = do
    a' <- yType a
    b' <- yType b
    return $ Y.ARR [a', b']
yType t = fail $ "Cannot compile to yices: " ++ pretty t

-- yDec
--   Assumes the declaration is monomorphic.
yDec :: Dec -> YCompiler [Y.CmdY]
yDec (ValD (TopSig n [] t) e) = do
    yt <- lift $ yType t
    ye <- yExp e
    return [Y.DEFINE (yicesname n, yt) (Just ye)]
yDec (DataD "Integer" _ _) =
    let deftype = Y.DEFTYP "Integer" (Just (Y.VarT "int"))
    in return [deftype]
yDec (DataD n [] cs) =
    let con :: Con -> YCompiler (String, [(String, Y.TypY)])
        con (Con n ts) = do 
            ts' <- lift $ mapM yType ts
            return (yicesname n, zip [yicesname n ++ show i | i <- [0..]] ts')

        -- Wrap each constructor in a function which supports partial
        -- application.
        mkcons :: Con -> YCompiler Y.CmdY
        mkcons (Con cn ts) = do
            yts <- lift $ mapM yType ts
            let ft a b = Y.ARR [a, b]
            let yt = foldr ft (Y.VarT (yicesname n)) yts
            let fe (n, t) e = Y.LAMBDA [(n, t)] e
            let names = [[c] | c <- take (length ts) "abcdefghijklmnop"]
            let body =  if null ts
                          then Y.VarE (yicesname cn)
                          else Y.APP (Y.VarE (yicesname cn)) (map Y.VarE names)
            let ye = foldr fe body (zip names yts)
            return $ Y.DEFINE (yicescon cn, yt) (Just ye)
    in do
        cs' <- mapM con cs
        let deftype = Y.DEFTYP (yicesname n) (Just (Y.DATATYPE cs'))
        defcons <- mapM mkcons cs
        return $ deftype : defcons

-- Integer Primitives
yDec (PrimD (TopSig "__prim_add_Integer" _ _))
 = return [defiop "__prim_add_Integer" "+"]
yDec (PrimD (TopSig "__prim_sub_Integer" _ _))
 = return [defbop "__prim_sub_Integer" "-"]
yDec (PrimD (TopSig "<" _ _)) = return [defbop "<" "<"]
yDec (PrimD (TopSig ">" _ _)) = return [defbop ">" ">"]
yDec (PrimD (TopSig "__prim_eq_Integer" _ _))
 = return [defbop "__prim_eq_Integer" "="]

yDec d = yfail $ "Cannot compile to yices: " ++ pretty d

-- defiop name type op
--   Define a primitive binary integer operation.
--   name - the name of the primitive
--   op - the integer operation.
defiop :: String -> String -> Y.CmdY
defiop name op =
    Y.DEFINE (yicesname name, Y.VarT "(-> Integer (-> Integer Integer))")
        (Just (Y.VarE $
            "(lambda (a::Integer) (lambda (b::Integer) (" ++ op ++ " a b)))"))

-- defbop name type op
--   Define a primitive binary integer predicate.
--   name - the name of the primitive
--   op - the predicate operator.
defbop :: String -> String -> Y.CmdY
defbop name op =
    Y.DEFINE (yicesname name, Y.VarT "(-> Integer (-> Integer Bool))")
        (Just (Y.VarE $ unlines [
                "(lambda (a::Integer) (lambda (b::Integer)",
                " (if (" ++ op ++ " a b) True False)))"]))


-- Given a seri identifer, turn it into a valid yices identifier.
-- TODO: hopefully our choice of names won't clash with the users choices...
--
-- I don't have documentation for what yices allows in names, but it appears
-- symbols aren't allowed. So this just replaces each symbol with an ascii
-- approximation.
yicesname :: String -> String
yicesname [] = []
-- TODO: renaming of 'not' should be part of builtins, it should not go here.
yicesname "not" = "_not"
yicesname ('!':cs) = "__bang" ++ yicesname cs
yicesname ('#':cs) = "__hash" ++ yicesname cs
yicesname ('$':cs) = "__dollar" ++ yicesname cs
yicesname ('%':cs) = "__percent" ++ yicesname cs
yicesname ('&':cs) = "__amp" ++ yicesname cs
yicesname ('*':cs) = "__star" ++ yicesname cs
yicesname ('+':cs) = "__plus" ++ yicesname cs
yicesname ('.':cs) = "__dot" ++ yicesname cs
yicesname ('/':cs) = "__slash" ++ yicesname cs
yicesname ('<':cs) = "__lt" ++ yicesname cs
yicesname ('=':cs) = "__eq" ++ yicesname cs
yicesname ('>':cs) = "__gt" ++ yicesname cs
yicesname ('?':cs) = "__ques" ++ yicesname cs
yicesname ('@':cs) = "__at" ++ yicesname cs
yicesname ('\\':cs) = "__bslash" ++ yicesname cs
yicesname ('^':cs) = "__hat" ++ yicesname cs
yicesname ('|':cs) = "__bar" ++ yicesname cs
yicesname ('-':cs) = "__dash" ++ yicesname cs
yicesname ('~':cs) = "__tilde" ++ yicesname cs
yicesname ('(':cs) = "__oparen" ++ yicesname cs
yicesname (')':cs) = "__cparen" ++ yicesname cs
yicesname (',':cs) = "__comma" ++ yicesname cs
yicesname (c:cs) = c : yicesname cs

