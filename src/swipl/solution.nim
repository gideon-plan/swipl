## SWI-Prolog solution iteration and variable binding extraction.

import std/tables

import basis/code/throw

import swipl/ffi
import swipl/glue
import swipl/dsl

standard_pragmas(effects=false, rise=false)

raises_error(sol_err, [IOError, KeyError], [])

# -----------------------------------------------------------------------
# Types
# -----------------------------------------------------------------------

type
  SolutionList* = seq[Solution]

  Solution* = ref object
    term*: term_t
    ok: bool
    case kind*: TermKind
    of pkAtom:
      name: cstring
      atom_val: atom_t
    of pkVar:
      variable*: cstring
    of pkInt:
      int_val*: int64
    of pkFloat:
      float_val*: cdouble
    of pkString:
      string_val*: cstring
    of pkNil, pkProgram:
      nil
    of pkFunctor, pkInfix:
      predicate_val: atom_t
      arity*: cint
      arguments*: SolutionList
    of pkModule:
      ns*: cstring
      module*: module_t
    of pkChars:
      char_val*: cstring
    of pkList:
      list*: SolutionList
    of pkBool:
      bool_val*: cint
    of pkDict:
      dict*: TableRef[string, Solution]

  SolutionError* = object of IOError

# -----------------------------------------------------------------------
# Solution
# -----------------------------------------------------------------------

let NULL_SOLUTION = Solution(kind: pkNil)

const SOLUTION_INDEX = "no solution at index"
const SOLUTION_KEY = "no solution matching key"

proc solution*(tr: term_t): Solution =
  result = Solution(kind: tr.kind, term: tr)
  case result.kind
  of pkString: result.string_val = ""
  of pkNil: result = NULL_SOLUTION
  of pkDict: result.dict = newTable[string, Solution]()
  of pkList: result.list = @[]
  of pkFunctor: result.arguments = @[]
  of pkChars: result.char_val = ""
  else: discard

proc copy*(s: Solution): Solution =
  Solution(term: PL_copy_term_ref(s.term), kind: s.kind)

proc `type`*(s: Solution): PLKind =
  PLKind(PL_term_type(s.term))

proc affinity*(s: Solution): TermKind =
  s.term.kind

proc `[]`*(s: Solution, index: Natural): Solution =
  case s.kind
  of pkFunctor, pkInfix: s.arguments[index]
  of pkList: s.list[index]
  else: raise newException(SolutionError, SOLUTION_INDEX)

proc `[]`*(s: Solution, key: string): Solution =
  if s.kind == pkDict: s.dict[key]
  else: raise newException(SolutionError, SOLUTION_KEY)

proc `$`*(s: Solution): string =
  case s.kind
  of pkVar: $s.variable
  of pkAtom: $s.name
  of pkInt: $s.int_val
  of pkFloat: $s.float_val
  of pkString: $s.string_val
  of pkFunctor, pkInfix: $s.arguments
  of pkNil, pkProgram: "nil"
  of pkModule:
    if s.ns == nil or s.ns.len == 0:
      $PL_atom_chars(PL_module_name(s.module))
    else: $s.ns
  of pkList: $s.list
  of pkChars: $s.char_val
  of pkBool: $s.bool_val
  of pkDict: glue.`$`(s.term)

proc len*(s: Solution): int =
  case s.kind
  of pkFunctor, pkInfix: s.arguments.len
  of pkDict: s.dict.len
  of pkList: s.list.len
  of pkNil, pkProgram: 0
  of pkBool: s.bool_val.ord
  else: 0

proc reset*(s: Solution): bool =
  PL_put_nil(s.term)

proc cmp*(s, o: Solution): int =
  PL_compare(s.term, o.term).ord

proc `==`*(s, o: Solution): bool =
  cmp(s, o) == 0

# -----------------------------------------------------------------------
# Solve
# -----------------------------------------------------------------------

const VAR_FLAG = CVT_VARIABLE or CVT_WRITE or REP_UTF8 or BUF_STACK
const STRING_FLAG = CVT_STRING or REP_UTF8 or BUF_STACK

proc solve*(s: Solution): Solution =
  var mark: buf_mark_t
  defer: PL_release_string_buffers_from_mark(mark)
  PL_mark_string_buffers(mark.addr)
  case s.affinity
  of pkVar: s.ok = PL_get_chars(s.term, s.variable.addr, VAR_FLAG)
  of pkAtom: s.ok = PL_get_atom_chars(s.term, s.name.addr)
  of pkInt: s.ok = PL_get_int64(s.term, s.int_val.addr)
  of pkFloat: s.ok = PL_get_float(s.term, s.float_val.addr)
  of pkString: s.ok = PL_get_chars(s.term, s.string_val.addr, STRING_FLAG)
  of pkNil: s.ok = true
  of pkFunctor:
    let source = PL_copy_term_ref(s.term)
    s.ok = PL_get_compound_name_arity(source, s.predicate_val.addr, s.arity.addr)
    for index in 1..s.arity:
      let t = PL_new_term_ref()
      s.ok = s.ok and PL_get_arg(index, source, t)
      s.arguments.add(t.solution.solve())
    s.term = source
  of pkModule: s.ok = PL_get_module(s.term, s.module.addr)
  of pkList:
    let source = PL_copy_term_ref(s.term)
    let target = PL_new_term_ref()
    var list = s.list
    while PL_get_list(source, target, source):
      list.add(target.solution.solve())
    s.term = source
    s.list = list
    s.ok = true
  else: s.ok = false
  s
