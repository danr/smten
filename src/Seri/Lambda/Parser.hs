
module Seri.Lambda.Parser (
    -- * The Seri Language
    -- $doc
    parse
    ) where

import Seri.Lambda.Parser.Grammar

-- $doc
-- The Seri language is a subset of haskell. The following lists the
-- differences between the Seri language and haskell as defined in the 
-- Haskell 98 Language Report.
--
-- [@Things to implement eventually, perhaps@]
--
-- - Layout is not supported.
--
-- - Explicit module exports are not allowed.
--
-- - The module name must be specified explicitly. Main will not be inferred.
--
-- - Qualified imports are not allowed.
--
-- - Importing a module under a different name using 'as' is not allowed.
--
-- - Import specifications are not supported.
--
-- - Type synonyms
--
-- - Contexts in data declarations
--
-- - Deriving clauses in data declarations
--
-- - Newtype declarations
--
-- - Contexts in class declarations
--
-- - Default declarations.
--
-- - Pattern bindings (?)
--
-- - Empty class declarations.
--
-- - Default class methods implementations.
--
-- - Multiple vars in a type signature.
-- 
-- - fixity declarations.
--
-- - Qualified names.
--
-- - Unparenthesized contexts.
--
-- - ! in constructor declarations.
--
-- - infix constructors.
--
-- - 'where' clauses in expressions.
--
-- - pattern guards.
--
-- - expression type signatures.
--
-- - infix operations that require precedence knowledge.
--
-- - arithmetic sequences.
--
-- - list comprehension.
--
-- - left and right sections.
--
-- - let statements in do notation.
--
-- - irrefutable patterns
-- 
-- - variable operators, such as (a `foo` b).
--
-- - float literals.
--
-- - pattern matching in let expressions.
--
-- - recursive let expressions (?).
--
-- [@Things meant to be different from haskell@]
--
-- - Extra semicolons are often allowed.
--
-- - Multi-param type classes are supported.
--
-- - variable signatures not accompanied by an implementation are allowed,
-- indicating a primitive variable.
--
-- - Empty data declarations are supported, indicating a primitive type.
--
--
-- [@Other Notes@]
--
-- - variables and constructors can be typed explicitly using a type signature
-- expression syntax. This is so pretty printed seri code with type
-- information can be parsed back in as is. You probably shouldn't rely on
-- this behavior.
--
-- - record constructors define variables for an undefined version of the
-- constructor (for Foo {}), and for updating (for x { foo = bar }).
-- This is not part of the haskell spec, but is used for implementation
-- purposes so label construction and update really is just syntactic sugar.
-- Your probably shouldn't rely on this behavior.
