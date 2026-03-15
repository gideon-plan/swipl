## SWI-Prolog term reference helpers and type conversion.

import basis/code/throw

import swipl/ffi
import swipl/dsl

standard_pragmas()

raises_error(pl_err, [IOError, ValueError], [RootEffect])

# -----------------------------------------------------------------------
# Term reference
# -----------------------------------------------------------------------

const CVT_FLAG = CVT_ALL or CVT_VARIABLE or CVT_WRITE or REP_UTF8 or BUF_STACK
const TERM_ERROR = "SWI-Prolog term init failed"

proc term_str*(tr: term_t): string {.pl_err.} =
  var cv: cstring
  if PL_get_chars(tr, cv.addr, CVT_FLAG): $cv else: "nil"

proc `$`*(tr: term_t): string {.pl_err.} =
  term_str(tr)

proc kind*(tr: term_t): TermKind {.pl_err.} =
  let t = PL_term_type(tr)
  if t == ord(plVariable): pkVar
  elif t == ord(plAtom): pkAtom
  elif t == ord(plInteger): pkInt
  elif t == ord(plFloat): pkFloat
  elif t == ord(plString): pkString
  elif t == ord(plList) or t == ord(plListPair): pkList
  elif t == ord(plTerm):
    if PL_is_list(tr): pkList
    elif PL_is_callable(tr): pkFunctor
    else: pkNil
  elif t == ord(plNil): pkFloat
  else: pkNil

# -----------------------------------------------------------------------
# Term from string
# -----------------------------------------------------------------------

proc term*(s: string): term_t {.pl_err.} =
  result = PL_new_term_ref()
  if not PL_chars_to_term(s.cstring, result):
    raise newException(IOError, TERM_ERROR & ": " & s)

proc module*(s: string): module_t {.ok.} =
  if s.len == 0: return nil
  var t = PL_new_term_ref()
  if PL_unify_atom_chars(t, s.cstring) and PL_get_module(t, result.addr): result else: nil

# -----------------------------------------------------------------------
# Term from Source
# -----------------------------------------------------------------------

proc term*(source: Source): term_t {.pl_err.} =
  term($source)

proc module*(source: Source): module_t {.ok.} =
  source.ns.module
