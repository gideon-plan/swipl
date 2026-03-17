## High-level SWI-Prolog API.

import std/exitprocs
import std/strformat
import std/strutils

import basis/code/throw

import swipl/ffi
import swipl/glue
import swipl/goal
import swipl/solution
import swipl/dsl

standard_pragmas(effects=false, rise=false)

# -----------------------------------------------------------------------
# Distinct string types
# -----------------------------------------------------------------------

type
  PrologTerm* = distinct string
  ModuleName* = distinct string

func `$`*(v: PrologTerm): string {.borrow.}
func `$`*(v: ModuleName): string {.borrow.}
func `==`*(a, b: PrologTerm): bool {.borrow.}
func `==`*(a, b: ModuleName): bool {.borrow.}
func len*(v: PrologTerm): int {.borrow.}
func len*(v: ModuleName): int {.borrow.}

# -----------------------------------------------------------------------
# Types
# -----------------------------------------------------------------------

type
  SWIPL* = ref object
    init*, opened*, termed*: bool
    max*: int
    flags: cint
    fid*: PL_fid_t

  QueryError* = object of IOError

# -----------------------------------------------------------------------
# Foreign frame
# -----------------------------------------------------------------------

proc frame*(engine: SWIPL) {.ok.} =
  engine.fid = PL_open_foreign_frame()

template scope*(engine: SWIPL, body: untyped): untyped =
  engine.frame()
  try:
    body
  finally:
    PL_close_foreign_frame(engine.fid)

template foreign*(engine: SWIPL, body: untyped): untyped =
  engine.frame()
  try:
    body
  finally:
    PL_discard_foreign_frame(engine.fid)

template rewind*(engine: SWIPL, body: untyped): untyped =
  body
  PL_rewind_foreign_frame(engine.fid)

# -----------------------------------------------------------------------
# Term
# -----------------------------------------------------------------------

proc clear_terms*(tr: term_t) {.ok.} =
  PL_reset_term_refs(tr)

proc clear_terms*(g: Goal) {.ok.} =
  PL_reset_term_refs(g.term)

# -----------------------------------------------------------------------
# Exception handling
# -----------------------------------------------------------------------

const PL_PASS = PL_Q_NODEBUG or PL_Q_CATCH_EXCEPTION or PL_Q_EXT_STATUS
const PL_DROP = PL_Q_NORMAL or PL_Q_EXT_STATUS
const QUERY_MSG = "SWI-Prolog query failed"

proc pass*(engine: SWIPL): SWIPL {.ok.} =
  engine.flags = PL_PASS.cint
  engine

proc drop*(engine: SWIPL): SWIPL {.ok.} =
  engine.flags = PL_DROP.cint
  engine

proc enable_debug*(engine: SWIPL, topic: PrologTerm): bool {.ok.} =
  PL_prolog_debug(($topic).cstring)

proc disable_debug*(engine: SWIPL, topic: PrologTerm): bool {.ok.} =
  PL_prolog_nodebug(($topic).cstring)

# -----------------------------------------------------------------------
# Assert
# -----------------------------------------------------------------------

proc assertz*(engine: SWIPL, tr: term_t, module: module_t = nil): bool {.ok.} =
  PL_assert(tr, module, PL_ASSERTZ.cint)

proc assertz*(engine: SWIPL, term: PrologTerm, module_name = ModuleName("")): bool =
  engine.assertz(($term).term, ($module_name).module)

proc assertz*(engine: SWIPL, source: Source): bool =
  engine.assertz(source.term, source.module)

proc asserta*(engine: SWIPL, tr: term_t, module: module_t = nil): bool {.ok.} =
  PL_assert(tr, module, PL_ASSERTA.cint)

proc asserta*(engine: SWIPL, term: PrologTerm, module_name = ModuleName("")): bool =
  engine.asserta(($term).term, ($module_name).module)

proc asserta*(engine: SWIPL, source: Source): bool =
  engine.asserta(source.term, source.module)

# -----------------------------------------------------------------------
# Library
# -----------------------------------------------------------------------

proc library*(engine: SWIPL, lib: string): bool =
  engine.assertz(PrologTerm("[library(" & lib & ")]"))

proc consult*(engine: SWIPL, file: string): bool =
  engine.assertz(PrologTerm("consult(" & file & ")"))

proc ensure*(engine: SWIPL, file: string): bool =
  engine.assertz(PrologTerm("ensure_loaded(" & file & ")"))

# -----------------------------------------------------------------------
# Call
# -----------------------------------------------------------------------

template call*(engine: SWIPL, tr: term_t, module: module_t = nil): bool =
  PL_call(tr, module)

proc call*(engine: SWIPL, term: PrologTerm, module_name = ModuleName("")): bool =
  engine.call(($term).term, ($module_name).module)

proc call*(engine: SWIPL, source: Source): bool =
  engine.call(source.term, source.module)

proc call*(engine: SWIPL, g: Goal): Solution =
  if g.unify() and engine.call(g.term, g.functor.module):
    return g.term.solution.solve()
  raise newException(QueryError, QUERY_MSG)

# -----------------------------------------------------------------------
# Predicate
# -----------------------------------------------------------------------

template solve*(engine: SWIPL, pred: predicate_t, args: term_t, module: module_t = nil): bool =
  PL_call_predicate(module, engine.flags, pred, args)

proc solve*(engine: SWIPL, g: Goal): Solution =
  if g.unify() and engine.solve(g.functor.predicate, g.functor.args.term, g.functor.module):
    return g.term.solution.solve()
  raise newException(QueryError, QUERY_MSG)

# -----------------------------------------------------------------------
# Query (iterator)
# -----------------------------------------------------------------------

proc exception(qid: qid_t) =
  let ex = PL_exception(qid)
  let msg = glue.`$`(ex)
  if msg.startsWith("error"):
    raise newException(QueryError, QUERY_MSG & ": " & msg)

iterator query*(engine: SWIPL, pred: predicate_t, tr: term_t; module: module_t = nil): Solution =
  let qid = PL_open_query(module, engine.flags, pred, tr)
  engine.opened = true
  try:
    var max = engine.max
    while max != 0:
      max -= 1
      let ns = PL_next_solution(qid)
      if ns == ord(queryException): qid.exception()
      elif ns == ord(queryFalse): break
      elif ns == ord(queryTrue): yield PL_copy_term_ref(tr).solution.solve()
      elif ns == ord(queryLast):
        yield PL_copy_term_ref(tr).solution.solve()
        break
  finally:
    discard PL_cut_query(qid)
    engine.opened = false

iterator query*(engine: SWIPL, g: Goal): Solution =
  if g.unify():
    for t in engine.query(g.functor.predicate, g.functor.args.term, g.functor.module): yield t
  else:
    raise newException(QueryError, QUERY_MSG)

# -----------------------------------------------------------------------
# Run (string evaluation)
# -----------------------------------------------------------------------

type RunResult* = tuple
  arguments, sol: term_t

const ONE* = 1.cint
const RUN_PRED = "eval".cstring
const RUN_ARITY = 2.cint
const RUN_ERROR = "Run predicate failed"
const DOT = "."

proc run_pred*(): predicate_t {.ok.} =
  PL_predicate(RUN_PRED, RUN_ARITY, nil)

proc eval*(term: string): RunResult =
  let arguments = PL_new_term_refs(RUN_ARITY)
  let expression = arguments
  if not PL_put_string_chars(expression, cstring(term & DOT)):
    raise newException(QueryError, RUN_ERROR)
  (arguments, term_t(uint(arguments) + uint(ONE)))

proc run*(engine: SWIPL, term: PrologTerm): Solution =
  let q = ($term).eval()
  if engine.solve(run_pred(), q.arguments, nil):
    return PL_copy_term_ref(q.sol).solution.solve()
  nil

proc run*(engine: SWIPL, source: Source): Solution =
  engine.run(PrologTerm($source))

iterator runs*(engine: SWIPL, term: PrologTerm): Solution =
  let q = eval($term)
  for t in engine.query(run_pred(), q.arguments, nil):
    yield q.sol.solution.solve()

iterator runs*(engine: SWIPL, source: Source): Solution =
  for t in engine.runs(PrologTerm($source)): yield t

# -----------------------------------------------------------------------
# FFI registration
# -----------------------------------------------------------------------

proc register*(name: PrologTerm, arity: int, funk: pl_function_t, flags: FFIFlag = ffiNONDET, module_name = ModuleName("")): bool {.ok.} =
  if module_name.len == 0:
    PL_register_foreign(($name).cstring, arity.cint, funk, flags.cint)
  else:
    PL_register_foreign_in_module(($module_name).cstring, ($name).cstring, arity.cint, funk, flags.cint)

# -----------------------------------------------------------------------
# Initialize
# -----------------------------------------------------------------------

when defined(windows):
  const ARGVS = ["libswipl.dll", "-q", "--nosignals"]
else:
  const ARGVS = ["swipl", "-q", "--nosignals"]

const ARGV_COUNT = ARGVS.len
const MAX = cint(-1)
const INIT_ERROR = "SWI-Prolog initialization failed"

proc close_swipl*() {.noconv, ok.} =
  if PL_is_initialised(nil, nil):
    discard PL_halt(getProgramResult().cint)

proc initialize*(max = MAX, do_drop = false): SWIPL =
  let ca = allocCStringArray(ARGVS)
  defer: deallocCStringArray(ca)
  if not PL_initialise(ARGV_COUNT, ca):
    raise newException(QueryError, INIT_ERROR)
  result = if do_drop: SWIPL(max: max).drop() else: SWIPL(max: max).pass()
  close_swipl.addExitProc()
  # Thread attach
  if PL_thread_self() != -1:
    case PL_thread_attach_engine(nil)
    of -1: raise newException(QueryError, "attach engine failed")
    of -2: raise newException(QueryError, "single-threaded library")
    else: discard
  # Register eval predicates
  let eval_src = prolog:
    eval(GoalString, BindingList) :- (
      atom_chars(A, GoalString),
      atom_to_term(A, Goal, BindingList),
      call(Goal)
    )
  let evaln = prolog:
    evaln(Atom) :- (
      term_to_atom(Expr, Atom),
      A is Expr,
      write(A),
      nl
    )
  result.foreign: result.init = result.assertz(eval_src) and result.assertz(evaln)
