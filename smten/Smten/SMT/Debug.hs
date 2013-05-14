
module Smten.SMT.Debug (debug) where

import System.IO

import Smten.SMT.Solver
import Smten.Name
import Smten.Sig
import Smten.ExpH
import Smten.Ppr

debug :: FilePath -> Solver -> IO Solver
debug f s = do
    fout <- openFile f WriteMode
    return $ Solver {
        push = hPutStrLn fout "push" >> push s,
        pop = hPutStrLn fout "pop" >> pop s,

        declare = \x -> do
            hPutStrLn fout $ "declare " ++ pretty x
            declare s x,

        assert = \e -> do
            hPutStrLn fout $ "assert " ++ pretty e
            assert s e,

        check = do
            hPutStr fout $ "check... "
            r <- check s
            hPutStrLn fout $ show r
            return r,

        getIntegerValue = \n -> do
            hPutStr fout $ unname n ++ " = "
            r <- getIntegerValue s n
            hPutStrLn fout $ show r
            return r,

        getBoolValue = \n -> do
            hPutStr fout $ unname n ++ " = "
            r <- getBoolValue s n
            hPutStrLn fout $ show r
            return r,

        getBitVectorValue = \w n -> do
            hPutStr fout $ unname n ++ " = "
            r <- getBitVectorValue s w n
            hPutStrLn fout $ show r
            return r
    }

