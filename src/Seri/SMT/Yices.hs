
module Seri.SMT.Yices (RunOptions(..), runYices) where

import Data.Generics
import Data.List((\\))
import Data.Maybe(fromMaybe)

import System.IO

import Control.Monad.State
import Math.SMT.Yices.Pipe
import qualified Math.SMT.Yices.Syntax as Y

import Seri.Target.Yices.Compiler
import Seri.Target.Yices.Yices

import Seri.Lambda
import Seri.Utils.Ppr

data YicesState = YicesState {
    ys_decls :: [Dec],
    ys_ipc :: YicesIPC,
    ys_dh :: Handle,
    ys_freeid :: Integer
}

type YicesMonad = StateT YicesState IO

sendCmds :: [Y.CmdY] -> YicesIPC -> Handle -> IO ()
sendCmds cmds ipc dh = do
    hPutStr dh (unlines (map show cmds))
    runCmdsY' ipc cmds

runCmds :: [Y.CmdY] -> YicesMonad ()
runCmds cmds = do
    ipc <- gets ys_ipc
    dh <- gets ys_dh
    lift $ sendCmds cmds ipc dh

-- Tell yices about any types or expressions needed to refer to the given
-- object.
declareNeeded :: (Data a) => Env a -> YicesMonad ()
declareNeeded x = do
  decs <- gets ys_decls
  let (pdecls, []) = sort $ decls (minimize x)
  let newdecls = pdecls \\ decs
  modify $ \ys -> ys { ys_decls = decs ++ newdecls }
  runCmds (yDecs newdecls)

runQuery :: Rule YicesMonad -> Env Exp -> YicesMonad Exp
runQuery gr e = do
    elaborated <- elaborate gr e
    case elaborated of
        (AppE (PrimE (Sig "query" _)) arg) -> do
            dh <- gets ys_dh
            ipc <- gets ys_ipc
            res <- lift $ checkY ipc
            lift $ hPutStrLn dh $ ">> check returned: " ++ show res 
            -- TODO: Read the evidence and return the appropriate expression
            -- when satisfiable.
            case res of 
                Unknown _ -> return $ ConE (Sig "Unknown" (AppT (ConT "Answer") (typeof arg)))
                Sat _ -> return $ AppE (ConE (Sig "Satisfiable" (AppT (ConT "Answer") (typeof arg)))) (PrimE (Sig "undefined" (typeof arg)))
                _ -> return $ ConE (Sig "Unsatisfiable" (AppT (ConT "Answer") (typeof arg)))
        (PrimE (Sig "free" (AppT (ConT "Query") t))) -> do
            fid <- gets ys_freeid
            modify $ \ys -> ys {ys_freeid = fid+1}
            
            declareNeeded (withenv e t)
            runCmds [Y.DEFINE ("free_" ++ show fid, yType t) Nothing]
            return (AppE (PrimE (Sig "realize" (AppT (AppT (ConT "->") (AppT (ConT "Free") t)) t))) (AppE (ConE (Sig "Free" (AppT (AppT (ConT "->") (ConT "Integer")) (AppT (ConT "Free") t)))) (IntegerE fid)))
        (AppE (PrimE (Sig "assert" _)) p) -> do
            declareNeeded (withenv e p)
            runCmds [Y.ASSERT (yExp p)]
            return (ConE (Sig "()" (ConT "()")))
        (AppE (PrimE (Sig "scoped" _)) q) -> do
            odecls <- gets ys_decls
            runCmds [Y.PUSH]
            r <- runQuery gr (withenv e q)
            runCmds [Y.POP]
            modify $ \ys -> ys { ys_decls = odecls }
            return r
        (AppE (PrimE (Sig "return_query" _)) x) -> return x
        (AppE (AppE (PrimE (Sig "bind_query" _)) x) f) -> do
          result <- runQuery gr (withenv e x)
          runQuery gr (withenv e (AppE f result))
        (AppE (AppE (PrimE (Sig "nobind_query" _)) x) y) -> do
          runQuery gr (withenv e x)
          runQuery gr (withenv e y)
        x -> error $ "unknown Query: " ++ render (ppr x)


yType :: Type -> Y.TypY
yType t = fromYCM $ compile_type smtY smtY t

yDecs :: [Dec] -> [Y.CmdY]
yDecs = compile_decs smtY

yExp :: Exp -> Y.ExpY
yExp e = fromYCM $ compile_exp smtY smtY e

data RunOptions = RunOptions {
    debugout :: Maybe FilePath,
    yicesexe :: FilePath
} deriving(Show)
            
runYices :: Rule YicesMonad -> RunOptions -> Env Exp -> IO Exp
runYices gr opts e = do
    dh <- openFile (fromMaybe "/dev/null" (debugout opts)) WriteMode
    ipc <- createYicesPipe (yicesexe opts) ["-tc"]
    sendCmds (includes smtY) ipc dh
    (x, _) <- runStateT (runQuery gr e) (YicesState [] ipc dh 1)
    hClose dh
    return x
    

smtY :: Compiler
smtY =
  let ye :: Compiler -> Exp -> YCM Y.ExpY
      ye _ (AppE (PrimE (Sig "realize" _)) (AppE (ConE (Sig "Free" _)) (IntegerE id))) = return $ Y.VarE ("free_" ++ show id)
      ye _ e = fail $ "smtY does not apply: " ++ render (ppr e)

      yt :: Compiler -> Type -> YCM Y.TypY
      yt _ t = fail $ "smtY does not apply: " ++ render (ppr t)
  in compilers [Compiler [] ye yt, yicesY]
