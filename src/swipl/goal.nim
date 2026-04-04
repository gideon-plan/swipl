{.experimental: "strictFuncs".}
## SWI-Prolog goal execution.

import std/[algorithm, sugar]

import basis/code/throw

import swipl/ffi
import swipl/glue
import swipl/dsl

standard_pragmas(effects=false, rise=false)

raises_error(goal_err, [IOError, ValueError], [RootEffect])

# -----------------------------------------------------------------------
# Types
# -----------------------------------------------------------------------

type
  Atom* = ref object
    value*: cstring
    point*: atom_t

  Functor* = ref object
    kind*: TermKind
    funk: functor_t
    pred: Atom
    arity*: cint
    args*: GoalList
    module*: module_t

  GoalList* = ref object
    term*: term_t
    index*: seq[Goal]
    source*: SourceList

  Goal* = ref object
    source*: Source
    term*: term_t
    ok: bool
    case kind*: TermKind
    of pkAtom: atom*: Atom
    of pkVar: variable*: cstring
    of pkInt: int_val*: int64
    of pkFloat: float_val*: cdouble
    of pkString: string_val*: cstring
    of pkNil: nil
    of pkFunctor, pkInfix: functor*: Functor
    of pkProgram: terms: GoalList
    of pkModule: module*: module_t
    of pkChars: char_val*: cstring
    of pkList: list*: GoalList
    of pkBool: bool_val*: cint
    of pkDict:
      tag*: Goal
      keys*: seq[atom_t]
      values*: GoalList

  GoalError* = object of IOError

# -----------------------------------------------------------------------
# Goal
# -----------------------------------------------------------------------

proc expand*(goal: Goal): Goal {.ok.} =
  goal.term = PL_new_term_ref()
  goal

proc copy*(goal: Goal): Goal {.ok.} =
  Goal(term: PL_copy_term_ref(goal.term), kind: goal.kind, source: goal.source)

proc `type`*(goal: Goal): PLKind {.ok.} =
  PLKind(PL_term_type(goal.term))

proc affinity*(goal: Goal): TermKind {.raises: [IOError, ValueError].} =
  goal.term.kind

proc cmp*(goal, other: Goal): int {.ok.} =
  PL_compare(goal.term, other.term).ord

proc `==`*(goal, other: Goal): bool {.ok.} =
  cmp(goal, other) == 0

proc `<`*(goal, other: Goal): bool {.ok.} =
  cmp(goal, other) == -1

proc reset*(goal: Goal): bool {.ok.} =
  PL_put_nil(goal.term)

proc goal*(tr: term_t): Goal {.goal_err.} =
  Goal(kind: tr.kind, term: tr)

proc goal*(source: Source): Goal {.ok.} =
  Goal(kind: source.kind, source: source, term: PL_new_term_ref())

proc goal*(source: Source, tr: term_t): Goal {.ok.} =
  Goal(kind: source.kind, term: tr, source: source)

# Forward declarations
proc `$`*(goal: Goal): string
proc unify*(goal: Goal): bool

# -----------------------------------------------------------------------
# GoalList
# -----------------------------------------------------------------------

proc `[]`*(gl: GoalList, index: Natural): Goal {.ok.} =
  gl.index[index.ord]

proc `[]=`*(gl: GoalList, index: Natural, goal: Goal) {.ok.} =
  gl.index[index.ord] = goal

proc add*(gl: GoalList, goal: Goal) {.ok.} =
  gl.index.add(goal)

iterator items*(gl: GoalList): Goal {.ok.} =
  for goal in gl.index: yield goal

proc len*(gl: GoalList): int {.ok.} =
  gl.index.len

proc reset*(gl: GoalList): bool {.ok.} =
  PL_put_nil(gl.term)

proc expand*(gl: GoalList): GoalList {.ok.} =
  let source = gl.source
  let length = source.len
  let refs = PL_new_term_refs(length.cint)
  gl.index = collect(newSeqOfCap(length)):
    for idx, ts in source: goal(ts, term_t(uint(refs) + uint(idx)))
  gl.term = refs
  gl

proc `$`*(gl: GoalList): string =
  $gl.index

proc to_list*(sl: SourceList): GoalList {.ok.} =
  GoalList(source: sl, index: @[])

proc to_list*(size: int): GoalList {.ok.} =
  GoalList(index: newSeqOfCap[Goal](size))

# -----------------------------------------------------------------------
# Atom
# -----------------------------------------------------------------------

proc atom_ref*(a: Atom): atom_t {.ok.} =
  if a.point == 0 and a.value != nil and a.value.len > 0:
    a.point = PL_new_atom(a.value)
  a.point

proc name*(a: Atom): cstring {.ok.} =
  if a.point != 0 and (a.value == nil or a.value.len == 0):
    a.value = PL_atom_chars(a.point)
  a.value

proc `$`*(a: Atom): string {.ok.} =
  if a.name != nil and a.name.len > 0: $a.name
  elif a.atom_ref != 0: $PL_atom_chars(a.atom_ref)
  else: ""

proc atom*(s: string): Atom {.ok.} =
  Atom(value: s.cstring)

proc atom*(a: atom_t): Atom {.ok.} =
  Atom(point: a, value: "")

proc atom*(source: Source): Atom {.goal_err.} =
  case source.kind
  of pkAtom: source.name.atom
  of pkDict: source.tag.atom
  else: raise newException(GoalError, "cannot create atom from " & $source.kind)

proc goal*(a: Atom): Goal {.ok.} =
  Goal(kind: pkAtom, atom: a)

# -----------------------------------------------------------------------
# Functor
# -----------------------------------------------------------------------

proc functor*(source: Source): Functor {.goal_err.} =
  if source.kind != pkFunctor:
    raise newException(SourceError, "invalid functor source")
  Functor(
    kind: pkFunctor,
    arity: source.arity.cint,
    pred: atom(source.predicate),
    args: source.args.to_list(),
  )

proc infix*(source: Source): Functor {.goal_err.} =
  if source.kind != pkInfix:
    raise newException(SourceError, "invalid infix source")
  Functor(
    kind: pkInfix,
    arity: 1 + source.body.len.cint,
    pred: source.operator.atom,
    args: (@[source.head] & source.body).to_list(),
  )

proc `[]`*(f: Functor, index: Natural): Goal {.ok_inline.} =
  f.args[index]

proc len*(f: Functor): int {.ok_inline.} =
  f.args.len

iterator items*(f: Functor): Goal {.ok.} =
  for gt in f.args: yield gt

proc atom_ref*(f: Functor): atom_t {.ok.} =
  f.pred.atom_ref

proc functor_ref*(f: Functor): functor_t {.ok.} =
  if f.funk == 0: f.funk = PL_new_functor(f.atom_ref, f.arity)
  f.funk

proc predicate*(f: Functor): predicate_t {.ok.} =
  PL_pred(f.functor_ref, f.module)

proc expand*(f: Functor): Functor =
  for g in f.args.expand():
    if not g.unify():
      raise newException(GoalError, "error filling functor arg")
  f

proc unify*(f: Functor): Functor =
  discard f.atom_ref
  discard f.functor_ref
  f.expand()

proc goal*(f: Functor): Goal =
  case f.kind
  of pkFunctor: Goal(kind: pkFunctor, functor: f)
  of pkInfix: Goal(kind: pkInfix, functor: f)
  else: raise newException(GoalError, "invalid functor kind")

# -----------------------------------------------------------------------
# Goal (full)
# -----------------------------------------------------------------------

proc len*(goal: Goal): int {.ok.} =
  case goal.kind
  of pkString: goal.string_val.len
  of pkFunctor, pkInfix: goal.functor.len
  of pkList: goal.list.len
  of pkChars: goal.char_val.len
  of pkDict: goal.values.len
  else: 0

proc `$`*(goal: Goal): string =
  case goal.kind
  of pkVar: $goal.variable
  of pkAtom: $goal.atom
  of pkInt: $goal.int_val
  of pkFloat: $goal.float_val
  of pkString: $goal.string_val
  of pkNil: "nil"
  of pkDict, pkFunctor, pkInfix: glue.`$`(goal.term)
  of pkModule: "module"
  of pkList: $goal.list.len
  of pkChars: $goal.char_val
  of pkBool: $goal.bool_val
  of pkProgram: $goal.terms

proc unify*(goal: Goal): bool =
  case goal.kind
  of pkVar: true
  of pkAtom:
    goal.atom = goal.source.atom
    PL_unify_atom_chars(goal.term, goal.atom.name)
  of pkInt:
    goal.int_val = goal.source.int_val
    PL_unify_int64(goal.term, goal.int_val)
  of pkFloat:
    goal.float_val = goal.source.float_val.cdouble
    PL_unify_float(goal.term, goal.float_val)
  of pkString:
    goal.string_val = goal.source.string_val.cstring
    PL_unify_string_chars(goal.term, goal.string_val)
  of pkNil: goal.reset()
  of pkFunctor, pkInfix:
    discard goal.functor.unify()
    PL_cons_functor_v(goal.term, goal.functor.functor_ref, goal.functor.args.term)
  of pkList:
    goal.ok = goal.reset()
    goal.list = goal.source.list.reversed().to_list().expand()
    for t in goal.list.index:
      if not t.unify():
        raise newException(GoalError, "error filling list term")
      goal.ok = goal.ok and PL_cons_list(goal.term, t.term, goal.term)
    goal.ok
  of pkChars:
    goal.char_val = goal.source.char_val
    PL_unify_chars(goal.term, plString.cint or REP_UTF8, goal.char_val.len.uint, goal.char_val)
  of pkBool:
    goal.bool_val = goal.source.bool_val.cint
    PL_unify_bool(goal.term, goal.bool_val)
  of pkDict:
    PL_chars_to_term(cstring($goal.source), goal.term)
  else: true
