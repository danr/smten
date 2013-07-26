
{-# LANGUAGE NoImplicitPrelude, RebindableSyntax #-}
module Smten.Sudoku.Board where

import Smten.Prelude
import Smten.Symbolic
import Smten.Sudoku.Cell


data Board c = Board [[c]]

printBoard :: (Cell c) => Board c -> [String]
printBoard (Board cells) = map (\row -> map printCell row) cells

rows :: (Cell c) => Board c -> [[c]]
rows (Board x) = x

cols :: (Cell c) => Board c -> [[c]]
cols (Board x) = transpose x

transpose :: [[a]] -> [[a]]
transpose [] = []
transpose ([]:_) = []
transpose xs = (map head xs) : transpose (map tail xs)

boxes :: (Cell c) => Board c -> [[c]]
boxes (Board rows) =
  let brows = breakup n rows
  in concat (map boxes' brows)

-- Given just 'm' rows, return the m boxes in those m rows.
boxes' :: [[a]] -> [[a]]
boxes' [] = []
boxes' ([]:_) = []
boxes' xs = 
  let b = concat (map (take n) xs)
      bs = map (drop n) xs
  in b : (boxes' bs)

-- Break a list up into a bunch of lists of the given length.
breakup :: Int -> [a] -> [[a]]
breakup _ [] = []
breakup n xs =
  case splitAt n xs of
     (a, b) -> a : (breakup n b)

isvalid :: (Eq c, Cell c) => Board c -> Bool
isvalid b = all distinctCell (concat [rows b, cols b, boxes b])

readRow :: (Cell c) => String -> Symbolic [c]
readRow = mapM readCell

readBoard :: (Cell c) => [String] -> Symbolic (Board c)
readBoard rows = do
    brows <- mapM readRow rows
    return (Board brows)

