
{-# LANGUAGE NoImplicitPrelude #-}
{-# OPTIONS_GHC -O #-}
module Smten.Data.Eq1 (Eq(..)) where

import Smten.Smten.Char
import Smten.Smten.Int
import Smten.Data.Bool
import Smten.Data.Char0
import Smten.Data.Eq0

infix 4 ==, /=

-- Note: this has to match the definition from Prelude
class Eq a where
    (==) :: a -> a -> Bool
    (==) x y = not (x /= y)

    (/=) :: a -> a -> Bool
    (/=) x y = not (x == y)

instance Eq Int where
    (==) = int_eq

instance Eq () where
    (==) () () = True

instance (Eq a, Eq b) => Eq (a, b) where
    (==) (a, b) (c, d) = (a == c) && (b == d)

instance (Eq a, Eq b, Eq c) => Eq (a, b, c) where
    (==) (a1, a2, a3) (b1, b2, b3) = (a1 == b1) && (a2 == b2) && (a3 == b3)

instance (Eq a) => Eq [a] where
    (==) [] [] = True
    (==) (a:as) (b:bs) = a == b && as == bs
    (==) _ _ = False

instance Eq Bool where
    (==) True True = True
    (==) True False = False
    (==) False True = False
    (==) False False = True

instance Eq Char where 
   (==) = char_eq


