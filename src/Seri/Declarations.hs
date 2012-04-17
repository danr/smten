
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TemplateHaskell #-}

module Seri.Declarations (
    SeriDec(..),
    declname, declidname,
    declval', declcon', decltype', declclass', declinst',
    declprim, declval, declcon, decltype, declclass, declcommit,
    ) where

import Data.Char(isUpper)
import Language.Haskell.TH

import Seri.THUtils
import qualified Seri.IR as SIR
import qualified Seri.Typed as S

class SeriDec a where
    dec :: a -> SIR.Dec

name_X :: String -> Name -> Name
name_X pre x = mkName $ pre ++ nameBase x

-- The name of the (possibly) polymorphic function generated.
declname :: Name -> Name
declname = name_X "_seriP_"

declidname :: Name -> Name
declidname = name_X "_seriI_"

declclname :: Name -> Name
declclname = name_X "SeriClass_"

declctname :: Name -> Name
declctname = name_X "_seriT_"

declprim :: SIR.Name -> Q Type -> Q [Dec]
declprim nm ty = declval nm ty [e| S.primitive $(litE (StringL nm)) |]

declcon :: String -> Q Type -> Q [Dec]
declcon n qt = do
    t <- qt
    return $ declcon' (mkName n) t

declval :: String -> Q Type -> Q Exp -> Q [Dec]
declval n qt qe = do
    t <- qt
    e <- qe
    return $ declval' (mkName n) t e

-- declval' name ty exp
-- Make a seri value declaration
--   name - name of the seri value being defined.
--   ty - the polymorphic haskell type of the expression.
--   exp - the value
--
-- For (contrived) example, given:
--  name: foo
--  ty: (Eq a) => a -> Integer
--  exp: lamE "x" (\x -> appE (varE "incr") (integerE 41))
--  iscon: False
--
-- The following haskell declarations are generated (approximately):
--  _seriP_foo :: (Eq a, SeriType a) => Typed Exp (a -> Integer)
--  _seriP_foo = lamE "x" (\x -> appE (varE "incr") (integerE 41))
--
--  _seriI_foo :: Typed Exp (a -> Integer) -> InstId
--  _seriI_foo _ = noinst
--
--  data SeriDec_foo = SeriDec_foo
--
--  instance SeriDec SeriDec_foo where
--      dec _ = valD "foo" (_seri_foo :: Typed Exp (VarT_a -> Integer))
declval' :: Name -> Type -> Exp -> [Dec]
declval' n t e =
  let dt = declize t
      sig_P = SigD (declname n) dt
      impl_P = FunD (declname n) [Clause [] (NormalB e) []]

      sig_I = SigD (declidname n) (declidize t)
      impl_I = FunD (declidname n) [Clause [WildP] (NormalB $ ConE 'SIR.NoInst) []]

      body = apply 'S.valD [string n, SigE (VarE (declname n)) (concretize dt)]
      ddec = decldec (name_X "SeriDecD_" n) body

  in [sig_P, impl_P, sig_I, impl_I] ++ ddec

-- declcon' name ty
-- Make a seri data constructor declaration
--   name - name of the seri data constructor being defined.
--   ty - the polymorphic haskell type of the expression.
--
-- For (contrived) example, given:
--  name: Foo
--  ty: a -> Bar
--
-- The following haskell declarations are generated (approximately):
--  _seri_Foo :: (SeriType a) => Typed Exp (a -> Bar)
--  _seri_Foo = conE' "Foo"
declcon' :: Name -> Type -> [Dec]
declcon' n t =
  let dt = declize t
      sig_P = SigD (declname n) dt
      impl_P = FunD (declname n) [Clause [] (NormalB (apply 'S.conE' [string n])) []]
  in [sig_P, impl_P]

-- decltype' 
-- Given a type declaration, make a seri type declaration for it, assuming the
-- type is already defined in haskell.
--
-- For example, given 
--    data Foo a = Bar Integer
--               | Sludge a
--
-- The following haskell declarations are generated:
--    instance SeriType1 Foo where
--       seritype1 _ = ConT "Foo"
--
--    data SeriDecD_Foo = SeriDecD_Foo
--
--    instance SeriDec SeriDecD_Foo where
--        dec _ = DataD "Foo" ["a"] [Con "Bar" [ConT "Integer"],
--                                   Con "Sludge" [ConT "VarT_a"]]
--
--    _seri_Bar :: Typed Exp (Integer -> Foo)
--    _seri_Bar = conE "Bar"
--
--    _seri_Sludge :: (SeriType a) => Typed Exp (a -> Foo)
--    _seri_Sludge = conE "Sludge"
--
-- Record type constructors are also supported, in which case the selector
-- functions will also be declared like normal seri values.
--
decltype' :: Dec -> [Dec]
decltype' (DataD [] dt vars cs _) =
 let numvars = length vars
     classname = "SeriType" ++ if numvars == 0 then "" else show numvars
     methname = "seritype" ++ if numvars == 0 then "" else show numvars
     vnames = map (\(PlainTV n) -> n) vars
     dtapp = appts $ (ConT dt):(map VarT vnames)

     -- Assuming the data type is polymorphic in type variables a, b, ...
     -- Given type t, return type (forall a b ... . t)
     --
     contextify :: Type -> Type
     contextify t = ForallT vars [] t

     -- contype: given the list of field types [a, b, ...] for a constructor
     -- form the constructor type: a -> b -> ... -> Foo
     contype :: [Type] -> Type
     contype ts = contextify $ arrowts (ts ++ [dtapp])

     -- produce the declarations needed for a given constructor.
     mkcon :: Con -> [Dec]
     mkcon (NormalC nc sts) =
        let ty = contype (map snd sts)
        in declcon' nc ty
     mkcon (RecC nc sts) =
        let ty = contype (map (\(_, _, t) -> t) sts)
            constrs = declcon' nc ty
            numfields = toInteger $ length sts

            mkacc :: Integer -> Name -> Type -> [Dec]
            mkacc i n st =
                let t = contextify $ arrowts [dtapp, st]
                    e = apply 'S.selector [string dt, integer i, integer numfields]
                in declval' n t e

            accessors = concat $ map (\(i, (n, _, t)) -> mkacc i n t) (zip [0..] sts)
        in constrs ++ accessors

     stimpl = FunD (mkName methname) [Clause [WildP] (NormalB (AppE (ConE 'SIR.ConT) (string dt))) []]
     stinst = InstanceD [] (AppT (ConT (mkName classname)) (ConT dt)) [stimpl]

     -- Given a constructor, return an expression corresponding to the Seri
     -- Con representing that constructor.
     mkconinfo :: Con -> Exp
     mkconinfo (NormalC n sts)
        = applyC 'SIR.Con [string n, ListE (map (\(_, t) -> seritypize t) sts)]
     mkconinfo (RecC n sts)
        = applyC 'SIR.Con [string n, ListE (map (\(_, _, t) -> seritypize t) sts)]

     body = applyC 'SIR.DataD [string dt, ListE (map string vnames), ListE (map mkconinfo cs)]
     ddec = decldec (name_X "SeriDecD_" dt) body

     constrs = concat $ map mkcon cs
 in [stinst] ++ ddec ++ constrs

decltype :: Name -> Q [Dec]
decltype nm = do
    TyConI d <- reify nm
    return $ decltype' d

-- declclass
-- Make a seri class declaration.
--
-- For example, given the class:
--   class Foo a where
--      foo :: a -> Integer
--
-- We generate:
--   class (SeriType a) => SeriClass_Foo a where
--     _seriP_foo :: Typed Exp (a -> Integer)
--     _seriI_foo :: Typed Exp (a -> Integer) -> InstId
--   
--   _seriT_foo :: a -> Typed Exp (a -> Integer)
--   _seriT_foo = undefined
-- 
--   data SeriDecC_Foo = SeriDecC_Foo
--   instance SeriDec SeriDecC_Foo where
--     dec = ClassD "Foo" ["a"] [Sig "foo" (VarT_a -> Integer)]
declclass' :: Dec -> [Dec]
declclass' (ClassD [] nm vars [] sigs) =
  let mksig :: Dec -> [Dec]
      mksig (SigD n t) =
        let dft = deforall t
            sig_P = SigD (declname n) (texpify dft)
            sig_I = SigD (declidname n) (arrowts [texpify dft, (ConT ''SIR.InstId)])
        in [sig_P, sig_I]

      ctx = map (\(PlainTV v) -> ClassP ''S.SeriType [VarT v]) vars
      class_D = ClassD ctx (declclname nm) vars [] (concat $ map mksig sigs)

      mkt :: Dec -> [Dec]
      mkt (SigD n t) = 
        let f t = arrowts $ map (\(PlainTV v) -> VarT v) vars ++ [texpify t]
            sig_T = SigD (declctname n) (ForallT vars [] (f (deforall t)))
            impl_T = FunD (declctname n) [Clause [WildP] (NormalB (VarE 'undefined)) []]
        in [sig_T, impl_T]

      type_ds = concat $ map mkt sigs


      mkdsig :: Dec -> Exp
      mkdsig (SigD n t) = applyC 'SIR.Sig [string n, seritypize t]

      tyvars = ListE $ map (\(PlainTV n) -> string n) vars
      dsigs = ListE $ map mkdsig sigs
      body = applyC 'SIR.ClassD [string nm, tyvars, dsigs]
      ddec = decldec (name_X "SeriDecC_" nm) body
      
  in [class_D] ++ type_ds ++ ddec

declclass :: Name -> Q [Dec]
declclass nm = do
    ClassI d _ <- reify nm
    return $ declclass' d

-- declinst
-- Make a seri instance declaration.
--
-- For example, given the instance
--   instance Foo Bool where
--      foo _ = 2
--
-- Generates:
--   instance SeriClass_Foo Bool where
--     _seriP_foo = ...
--     _seriI_foo _ = Inst "Foo" [Bool]

--   data SeriDecI_Foo$Bool = SeriDecI_Foo$Bool
--   instance SeriDec SeriDecI_Foo$Bool where
--     dec = InstD "Foo" [Bool] [
--             method "foo" (_seriT_foo (undefined :: Bool)) (...)
--             ]
--  
declinst' :: Dec -> [Dec]
declinst' i@(InstanceD [] tf@(AppT (ConT cn) t) impls) =
  let -- TODO: don't assume single param type class
      iname = string cn
      itys = ListE [seritypize t]

      mkimpl :: Dec -> [Dec]
      mkimpl (ValD (VarP n) (NormalB b) []) =
        let p = ValD (VarP (declname n)) (NormalB b) []
            i = FunD (declidname n) [Clause [WildP] (NormalB (applyC 'SIR.Inst [iname, itys])) []]
        in [p, i]

      idize :: Type -> String
      idize (AppT a b) = idize a ++ "$" ++ idize b
      idize (ConT nm) = nameBase nm

      impls' = concat $ map mkimpl impls
      inst_D = InstanceD [] (AppT (ConT (declclname cn)) t) impls'

      mkmeth (ValD (VarP n) (NormalB b) _) = 
        apply 'S.method [string n, AppE (VarE (declctname n)) (SigE (VarE 'undefined) t), b]

      methods = ListE $ map mkmeth impls
      body = applyC 'SIR.InstD [iname, itys, methods]
      ddec = decldec (mkName $ "SeriDecI_" ++ (idize tf)) body
   in [inst_D] ++ ddec

-- Given the raw haskell type corresponding to an expression, return the type
-- of the haskell function representing an expression of that type.
--
-- For example
--  input: (Eq a) => a -> Integer
--  output: (Eq a, SeriType a) => Typed Exp (a -> Integer) 
declize :: Type -> Type
declize ty = 
  let -- Given a type variable, figure out what predicate we should add for it
      -- in the context.
      --
      -- TODO: this is a bad special case hack. Can we come up with a better
      -- way for figuring out the kind of each type variable?
      stcon :: TyVarBndr -> Pred
      stcon (PlainTV x) | 'm' == head (nameBase x)
        = ClassP ''S.SeriType1 [VarT x]
      stcon (PlainTV x) = ClassP ''S.SeriType [VarT x]

  in case ty of
        ForallT vns ctx t -> ForallT vns (ctx ++ (map stcon vns)) (texpify t)
        t -> texpify t 

-- Given the raw haskell type corresponding to an expression, return the type
-- of the haskell function representing the InstId of that expression.
--
-- For example
--  input: (Eq a) => a -> Integer
--  output: Typed Exp (a -> Integer) -> InstId
declidize :: Type -> Type 
declidize ty =
  let mkt t = arrowts [texpify t, (ConT ''SIR.InstId)]
  in inforall mkt ty

-- Produce declarations for:
--  data <Name> = <Name>
--  instance SeriDec <Name> where
--      dec _ = <Exp>
decldec :: Name -> Exp -> [Dec]
decldec n body = 
  let data_D = DataD [] n [] [NormalC n []] []
      impl_D = FunD 'dec [Clause [WildP] (NormalB body) []]
      inst_D = InstanceD [] (AppT (ConT ''SeriDec) (ConT n)) [impl_D]
  in [data_D, inst_D]


texpify :: Type -> Type
texpify t = AppT (AppT (ConT ''S.Typed) (ConT ''SIR.Exp)) t

deforall :: Type -> Type
deforall (ForallT _ _ t) = t
deforall t = t

inforall :: (Type -> Type) -> Type -> Type
inforall f (ForallT vns ctx t) = ForallT vns ctx (f t)
inforall f t = f t

-- Given a type, return an expression corresonding to the seri type of
-- that type.
seritypize :: Type -> Exp
seritypize t = apply 'S.seritype [SigE (VarE 'undefined) (concretize t)]

-- Given a potentially polymorphic haskell type, convert it to a concrete
-- haskell type which represents the polymorphic seri type.
--
-- In other words, replace all occurences of VarT "foo" with VarT_foo.
concretize :: Type -> Type
concretize (ForallT _ _ t) = concretize t
concretize (VarT nm) = ConT $ mkName ("VarT_" ++ (nameBase nm))
concretize (AppT a b) = AppT (concretize a) (concretize b)
concretize t = t

-- Declarations may not be seen right away. Call this template haskell
-- function to force the declarations to be committed.
--
-- So, for example, to use this you would declare all your seri functions,
-- then below those in the source file call this as a top level template
-- haskell slice, then below that in the source file you can use quoted seri
-- expressions referring to the declarations.
declcommit :: Q [Dec]
declcommit = return []
