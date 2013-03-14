
-- | Syntactic sugar involving pattern matching.
module Smten.Exp.Match (
    Pat(..), Guard(..), Body(..), Alt(..), MAlt(..), WBodies(..),
    tupleP, listP, charP, stringP, numberP, sigP,
    mcaseE, clauseE, mlamE, mletE, mletsE,
    lcompE, normalB,
    simpleA, simpleMA,
    ) where

import Data.Functor((<$>))
import Data.Maybe(fromMaybe)

import Smten.Lit
import Smten.Name
import Smten.Type
import Smten.Sig
import Smten.Fresh
import Smten.Exp.Exp
import Smten.Exp.Utils
import Smten.Exp.Sugar

data Pat = ConP Name [Pat]
         | VarP Name
         | AsP Name Pat
         | LitP Exp
         | WildP
         | SigP Pat Type
    deriving (Eq, Show)

listP :: [Pat] -> Pat
listP [] = ConP (name "[]") []
listP (x:xs) = ConP (name ":") [x, listP xs]

charP :: Char -> Pat
charP = LitP . litE . charL

stringP :: String -> Pat
stringP = listP . map charP

numberP :: Integer -> Pat
numberP = LitP . numberE

tupleP :: [Pat] -> Pat
tupleP ps = ConP (tupleN (length ps)) ps

sigP :: Pat -> Type -> Pat
sigP = SigP

-- Share the given expression properly.
sharedM :: Exp -> (Exp -> Fresh Exp) -> Fresh Exp
sharedM x f | isSimple x = f x
sharedM x f = do
   xv <- fresh (Sig (name "_s") UnknownT)
   body <- f (varE xv)
   return $
     if xv `elem` (free body)
        then  letE xv x body 
        else body

-- | Perform a pattern match.
-- case x of
--     p -> yv
--     _ -> n
patM :: Exp -> Pat -> Exp -> Exp -> Fresh Exp
patM _ WildP yv _ = return yv
patM x (VarP n) yv _ = return $ appE (lamE (Sig n UnknownT) yv) x
patM x (AsP nm p) yv n = do
    rest <- patM x p yv n
    return $ letE (Sig nm (typeof x)) x rest
patM x (LitP e) yv n =
  let p = appsE (varE (Sig (name "==") UnknownT)) [e, x]
  in return $ ifE p yv n
patM x (SigP p t) yv n = patM (sigE x t) p yv n
patM x (ConP nm ps) yv n = sharedM n $ \nv -> do
      y <- clauseM [simpleMA ps yv []] nv
      return $ CaseE x (Sig nm UnknownT) y nv

data Guard = PatG Pat Exp
           | LetG [(Pat, Exp)]
           | BoolG Exp
    deriving (Eq, Show)

-- | Perform a guard match
--   | g = y
--   | otherwise = n
guardM :: Guard -> Exp -> Exp -> Fresh Exp
guardM (PatG p x) y n = patM x p y n
guardM (LetG decls) y _ = return (mletsE decls y)
guardM (BoolG x) y n = return (ifE x y n)

-- | Perform multiple guard matches
--   | g1, g2, ... = y
--   | otherwise = n
guardsM :: [Guard] -> Exp -> Exp -> Fresh Exp
guardsM [] y _ = return y 
guardsM (g:gs) y n = sharedM n $ \nv -> do
    y' <- guardsM gs y nv
    guardM g y' nv

data Body = Body [Guard] Exp
    deriving (Eq, Show)

bodyM :: Body -> Exp -> Fresh Exp
bodyM (Body gs y) n = guardsM gs y n

bodiesM :: [Body] -> Exp -> Fresh Exp
bodiesM [] n = return n
bodiesM (b:bs) n = do
    n' <- bodiesM bs n
    bodyM b n'

-- Bodies with a where clause
data WBodies = WBodies [Body] [(Pat, Exp)]
    deriving (Eq, Show)

wbodiesM :: WBodies -> Exp -> Fresh Exp
wbodiesM (WBodies bs ls) n = mletsE ls <$> bodiesM bs n

data Alt = Alt Pat WBodies
    deriving (Eq, Show)

simpleA :: Pat -> Exp -> [(Pat, Exp)] -> Alt
simpleA p e ls = Alt p (WBodies [Body [] e] ls)

-- Match a single alternative:
--  case x of
--    alt 
--    _ -> n
altM :: Exp -> Alt -> Exp -> Fresh Exp
altM x (Alt p bs) n = sharedM n $ \nv -> do
    body <- wbodiesM bs nv
    patM x p body nv

-- Match multiple alternatives:
--   case x of
--     alt1 
--     alt2
--     ...
--     _ -> n
altsM :: Exp -> [Alt] -> Exp -> Fresh Exp
altsM _ [] n = return n
altsM x (a:as) n = sharedM x $ \xv -> do
    n' <- altsM xv as n
    altM xv a n'

data MAlt = MAlt [Pat] WBodies
    deriving (Eq, Show)

simpleMA :: [Pat] -> Exp -> [(Pat, Exp)] -> MAlt
simpleMA ps e ls = MAlt ps (WBodies [Body [] e] ls)

-- Match a multi-argument alternative
maltM :: [Sig] -> MAlt -> Exp -> Fresh Exp
maltM args (MAlt ps b) n = do
  let -- case a b c of
      --    pa pb pc -> yv
      --    _ -> n
      --
      -- Translates to:
      --  \a b c -> 
      --     case a of
      --        pa -> case b of
      --                pb -> case c of 
      --                        pc -> yv
      --                        _ -> n
      --                _ -> n
      --        _ -> n
      mkcases :: [(Pat, Exp)] -> WBodies -> Exp -> Fresh Exp
      mkcases [] bs n = wbodiesM bs n
      mkcases ((p, x):ps) y n = sharedM n $ \nv -> do
        body <- mkcases ps y nv
        patM x p body nv
  mkcases (zip ps (map varE args)) b n

-- Match multiple multi-argument alternatives
maltsM :: [Sig] -> [MAlt] -> Exp -> Fresh Exp
maltsM args [] n = return n
maltsM args (m:ms) n = do
    n' <- maltsM args ms n
    maltM args m n'

-- | Desugar a case expression.
mcaseE :: Exp -> [Alt] -> Exp
mcaseE x alts
 = runFresh $ altsM x alts (errorE "case no match")

clauseE :: [MAlt] -> Exp
clauseE ms = runFresh $ clauseM ms (errorE "case no match")

clauseM :: [MAlt] -> Exp -> Fresh Exp
clauseM [MAlt ps e] n = do
  -- If we are only making one match, we pick the variables for the lambda
  -- more wisely to avoid silly things like:
  --    \_p1 -> let a = _p1
  --            in foo a
  -- This doesn't work if there are multiple matches because there are scoping
  -- issues then.
  let mkvar :: Pat -> Fresh (Sig, Pat)
      mkvar (VarP n) = return (Sig n UnknownT, WildP)
      mkvar (AsP n p) = return (Sig n UnknownT, p)
      mkvar p = do  
        s <- fresh $ Sig (name "_p") UnknownT
        return (s, p)
  pvs <- mapM mkvar ps
  let (vars, ps') = unzip pvs
  b <- maltM vars (MAlt ps' e) n
  return $ lamsE vars b

clauseM ms@(MAlt ps _ : _) n = do
    vars <- mapM fresh [Sig (name $ "_p" ++ show i) UnknownT | i <- [1..(length ps)]]
    b <- maltsM vars ms n
    return $ lamsE vars b

-- | Lambda with pattern matching.
mlamE :: [Pat] -> Exp -> Exp
mlamE ps e = clauseE [simpleMA ps e []]

-- | Let with pattern matching
mletE :: Pat -> Exp -> Exp -> Exp
mletE  p v e = mcaseE v [simpleA p e []]

-- | Sequential let with pattern matching
mletsE :: [(Pat, Exp)] -> Exp -> Exp
mletsE [] x = x
mletsE ((p, v):ps) x = mletE p v (mletsE ps x)

-- Return true if the expression is simple.
-- If an expression is simple, there's no cost to duplicating it.
isSimple :: Exp -> Bool
isSimple (AppE {}) = False
isSimple (LamE {}) = False
isSimple (CaseE {}) = False
isSimple _ = True

-- | List comprehension.
lcompE :: Exp -> [Guard] -> Exp
lcompE e [BoolG t] | t == trueE = listE [e]
lcompE e [q] = lcompE e [q, BoolG trueE]
lcompE e (BoolG b : qs) = ifE b (lcompE e qs) (listE [])
lcompE e (PatG p l : qs) = 
  let ok = clauseE [
            simpleMA [p] (lcompE e qs) [],
            simpleMA [WildP] (listE []) []
           ]
  in appsE (varE (Sig (name "concatMap") UnknownT)) [ok, l]
lcompE e (LetG decls : qs) = mletsE decls (lcompE e qs)

normalB :: Exp -> Body
normalB = Body []

