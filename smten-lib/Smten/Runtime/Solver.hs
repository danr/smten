
module Smten.Runtime.Solver (
    Solver, SolverInst(..), solverInstFromAST,
    ) where

import Smten.Runtime.Formula
import Smten.Runtime.Result
import qualified Smten.Runtime.SolverAST as AST
import qualified Smten.Runtime.Assert as A

type Solver = IO SolverInst

data SolverInst = SolverInst {
    -- | Assert the given expression.
    assert :: BoolF -> IO (),

    -- | Declare a free variable with given name and type.
    declare :: TypeF -> String -> IO (),

    getBoolValue :: String -> IO Bool,

    -- | Run (check) and return the result.
    check :: IO Result
}

solverInstFromAST :: (AST.SolverAST ctx exp) => ctx -> SolverInst
solverInstFromAST x = SolverInst {
    assert = A.assert x,
    declare = AST.declare x,
    getBoolValue = AST.getBoolValue x,
    check = AST.check x
}

