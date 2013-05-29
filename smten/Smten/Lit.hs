
{-# LANGUAGE PatternGuards #-}

module Smten.Lit (
    Lit(),
    integerL, de_integerL,
    charL, de_charL,
    bitL, de_bitL,
    dynamicL, de_dynamicL,
    ) where

import Data.Typeable
import Data.Dynamic

import Smten.Bit
import Smten.Ppr

newtype Lit = Lit Dynamic
    deriving (Show)

instance Eq Lit where
    (==) a b
      | Just ai <- de_integerL a
      , Just bi <- de_integerL b = ai == bi
      | Just ac <- de_charL a
      , Just bc <- de_charL b = ac == bc
      | otherwise = False

dynamicL :: (Typeable a) => a -> Lit
dynamicL = {-# SCC "dynamicL" #-} Lit . toDyn

de_dynamicL :: (Typeable a) => Lit -> Maybe a
de_dynamicL (Lit x) = {-# SCC "de_dynamicL" #-} fromDynamic x

integerL :: Integer -> Lit
integerL = {-# SCC "integerL" #-} dynamicL

de_integerL :: Lit -> Maybe Integer
de_integerL = {-# SCC "de_integerL" #-} de_dynamicL

charL :: Char -> Lit
charL = {-# SCC "charL" #-} dynamicL

de_charL :: Lit -> Maybe Char
de_charL = {-# SCC "de_charL" #-} de_dynamicL

bitL :: Bit -> Lit
bitL = {-# SCC "bitL" #-} dynamicL

de_bitL :: Lit -> Maybe Bit
de_bitL = {-# SCC "de_bitL" #-} de_dynamicL

instance Ppr Lit where
    ppr l
      | Just i <- de_integerL l = integer i
      | Just c <- de_charL l = text (show c)
      | Just b <- de_bitL l = text (show b)
      | otherwise = text "?Lit?"

