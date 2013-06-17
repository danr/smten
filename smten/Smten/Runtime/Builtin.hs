
module Smten.Runtime.Builtin (
    SmtenHS0(..), SmtenHS1(..), SmtenHS2(..), SmtenHS3(..), SmtenHS4(..),
    Haskelly(..),
    Cases, concrete,
    Assignment,
    primcase, realize,
    Bool(True, False), __caseTrue, __caseFalse, Integer(Integer), Char(Char),
    NumT, (:+:), (:-:), (:*:),
    ) where

import qualified Prelude
import Smten.Runtime.SmtenHS
import Smten.Runtime.Char
import Smten.Runtime.Numeric hiding (Integer)

