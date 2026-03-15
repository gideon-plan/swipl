## SWI-Prolog C API bindings.
##
## Source: SWI-Prolog.h from SWI-Prolog 10.0.2.
## Ported from gideon archive (8.x target).

{.push cdecl.}
{.push header: "<SWI-Prolog.h>".}

import std/macros

import basis/bit/clang

# Inlined from archive code/compat -- creates a distinct int32 with arithmetic ops
macro define_enum*(typ: untyped): untyped =
  result = newNimNode(nnkStmtList)
  result.add quote do:
    type `typ`* = distinct int32
  for i in ["+", "-", "*", "div", "mod", "shl", "shr", "or", "and", "xor", "<", "<=", "==", ">", ">="]:
    let ni = newIdentNode(i)
    let typout = if i[0] in "<=>": newIdentNode("bool") else: typ
    if i[0] == '>':
      let nopp = if i.len == 2: newIdentNode("<=") else: newIdentNode("<")
      result.add quote do:
        proc `ni`*(x: `typ`, y: int32): `typout` = `nopp`(y, x)
        proc `ni`*(x: int32, y: `typ`): `typout` = `nopp`(y, x)
        proc `ni`*(x, y: `typ`): `typout` = `nopp`(y, x)
    else:
      result.add quote do:
        proc `ni`*(x: `typ`, y: int32): `typout` {.borrow.}
        proc `ni`*(x: int32, y: `typ`): `typout` {.borrow.}
        proc `ni`*(x, y: `typ`): `typout` {.borrow.}
    result.add quote do:
      proc `ni`*(x: `typ`, y: int): `typout` = `ni`(x, y.int32)
      proc `ni`*(x: int, y: `typ`): `typout` = `ni`(x.int32, y)
  let divop = newIdentNode("/")
  let dlrop = newIdentNode("$")
  let notop = newIdentNode("not")
  result.add quote do:
    proc `divop`*(x, y: `typ`): `typ` = `typ`((x.float / y.float).int32)
    proc `divop`*(x: `typ`, y: int32): `typ` = `divop`(x, `typ`(y))
    proc `divop`*(x: int32, y: `typ`): `typ` = `divop`(`typ`(x), y)
    proc `divop`*(x: `typ`, y: int): `typ` = `divop`(x, y.int32)
    proc `divop`*(x: int, y: `typ`): `typ` = `divop`(x.int32, y)
    proc `dlrop`*(x: `typ`): string {.borrow.}
    proc `notop`*(x: `typ`): `typ` {.borrow.}

##########
## Term ##
##########

define_enum(rc_cancel)

# Type...

type
  PLKind* {.size: sizeof(distinct cint).} = enum
    plVariable = 1            # PL_VARIABLE
    plAtom = 2                # PL_ATOM
    plInteger = 3             # PL_INTEGER
    plRational = 4            # PL_RATIONAL
    plFloat = 5               # PL_FLOAT
    plString = 6              # PL_STRING
    plTerm = 7                # PL_TERM
    plNil = 8                 # PL_NIL
    plBlob = 9                # PL_BLOB
    plListPair = 10           # PL_LIST_PAIR
    plFunctor = 11            # PL_FUNCTOR
    plList = 12               # PL_LIST
    plChars = 13              # PL_CHARS
    plPointer = 14            # PL_POINTER
    plCodeList = 15           # PL_CODE_LIST
    plCharList = 16           # PL_CHAR_LIST
    plBool = 17               # PL_BOOL
    plFunctorChars = 18       # PL_FUNCTOR_CHARS
    plPredicateIndicator = 19 # PL_PREDICATE_INDICATOR
    plShort = 20              # PL_SHORT
    plInt = 21                # PL_INT
    plLong = 22               # PL_LONG
    plDouble = 23             # PL_DOUBLE
    plNChars = 24             # PL_NCHARS
    plUTF8Chars = 25          # PL_UTF8_CHARS
    plUTF8String = 26         # PL_UTF8_STRING
    plInt64 = 27              # PL_INT64
    plNUTF8Chars = 28         # PL_NUTF8_CHARS
    plNUTF8Codes = 29         # PL_NUTF8_CODES
    plNUTF8String = 30        # PL_NUTF8_STRING
    plNWChars = 31            # PL_NWCHARS
    plNWCodes = 32            # PL_NWCODES
    plNWString = 33           # PL_NWSTRING
    plMBChars = 34            # PL_MBCHARS
    plMBCodes = 35            # PL_MBCODES
    plMBString = 36           # PL_MBSTRING
    plIntPtr = 37             # PL_INTPTR
    plChar = 38               # PL_CHAR
    plCode = 39               # PL_CODE
    plByte = 40               # PL_BYTE
    plPartialList = 41        # PL_PARTIAL_LIST
    plCyclicTerm = 42         # PL_CYCLIC_TERM
    plNotAList = 43           # PL_NOT_A_LIST
    plDict = 44               # PL_DICT

  PLKinds* = set[PLKind]

proc to_int*(f: PLKinds): int = cast[cint](f)

proc to_kind*(v: int): PLKinds = cast[PLKinds](v)

converter to_bool*(t: CBool): bool = ord(t) != 0

##########
## Term ##
##########

## 🗹: Term reference.
type term_t* {.importc.} = culong

## 🗹: Get type of Prolog term reference.
proc PL_term_type*(t: term_t): cint {.importc.}

## 🗹: Compares two term references using standard order and returns -1, 0 or 1
proc PL_compare*(t1, t2: term_t): cint {.importc.}

## 🗹: Discover if term reference is ground term.
proc PL_is_ground*(t: term_t): cint {.importc.}

## 🗹: Discover if term reference is acyclical.
proc PL_is_acyclic*(t: term_t): cint {.importc.}

#[

Term: value in Prolog.

A term is either a `variable`, `atom`, `integer`, `float`, or `compound`.

SWI-Prolog adds the type `string`.

]#

# reference...

## 🗹: Create fresh term reference.
proc PL_new_term_ref*(): term_t {.importc.}

## 🗹: Create `n` fresh term references.
proc PL_new_term_refs*(n: cint): term_t {.importc.}

## 🗹: Create fresh term reference pointing to an existing term reference.
proc PL_copy_term_ref*(t: term_t): term_t {.importc.}

## 🗹: Destroy passed term plus all term references that have been created since it was created.
proc PL_reset_term_refs*(after: term_t) {.importc.}

#[

Unify: Prolog process to make two terms equal by assigning variables in one term to values at the corresponding location
of the other term.

Example:

?- foo(a, B) = foo(A, b).
A = a,
B = b.

Unlike assignment in other programming languages, which does not exist in Prolog, unification is not directed.

]#

const
  CVT_ATOM* = 0x00000001
  CVT_FLOAT* = 0x00000020
  CVT_INTEGER* = 0x00000008
  CVT_LIST* = 0x00000004
  CVT_MASK* = 0x00000FFF
  CVT_RATIONAL* = 0x00000010
  CVT_STRING* = 0x00000002
  CVT_VARIABLE* = 0x00000040
  CVT_WRITE_CANONICAL* = 0x00000080
  CVT_WRITE* = 0x00000080
  CVT_WRITEQ* = 0x000000C0
  CVT_EXCEPTION* = 0x00001000
  CVT_VARNOFAIL* = 0x00002000
  CVT_NUMBER* = (CVT_RATIONAL or typeof(CVT_RATIONAL)(CVT_FLOAT))
  CVT_ATOMIC* = (CVT_NUMBER or typeof(CVT_NUMBER)(CVT_ATOM) or typeof(CVT_NUMBER)(CVT_STRING))
  CVT_ALL* = (CVT_ATOMIC or typeof(CVT_ATOMIC)(CVT_LIST))

## 🗹: Unify two Prolog term references.
proc PL_unify*(t1, t2: term_t): CBool {.importc.}

## 🗹: Unify term reference with compound terms.
proc PL_unify_term*(t: term_t): CBool {.importc, varargs.}

# 🞎:
proc PL_put_term*(t1, t2: term_t): CBool {.importc.}

# 🞎:
proc PL_chars_to_term*(chars: cstring; term: term_t): CBool {.importc.}

##########
## Atom ##
##########

#[
Atom: textual constant.

Used as name for compound terms, to represent constants or text.
]#

type
  atom_t* {.importc.} = culong

  Type_SWIPrologh1* {.bycopy, importc: "struct Type_SWIPrologh1".} = object
    name*: atom_t
    arity*: uint

  Union_SWIPrologh1* {.union, bycopy, importc: "union Union_SWIPrologh1".} = object
    i*: ptr uint # integer reference value
    a*: atom_t # atom reference value

const
  # Atomic constant representing the empty list `[]`.
  ATOM_nil* = (0)
  # Atomic constant representing the empty list `.(_|_)` or '[|]'(_,_)`
  ATOM_dot* = (1)

## 🗹: Base of reserved (meta-)atoms
proc PL_atoms*(): ptr atom_t {.importc: "_PL_atoms".}

## 🗹: Get atom from term.
proc PL_get_atom*(t: term_t; a: ptr atom_t): CBool {.importc.}

## 🗹: Get atom from term but raise exception if term isn't an atom.
proc PL_get_atom_ex*(t: term_t; a: ptr atom_t): CBool {.importc.}

## 🗹: Discover if term is an atom.
proc PL_is_atom*(t: term_t): CBool {.importc.}

## 🗹: Create new atom from string.
proc PL_new_atom*(s: cstring): atom_t {.importc.}

# 🞎:
proc PL_unify_atom*(t: term_t; a: atom_t): CBool {.importc.}

# 🞎:
proc PL_put_atom*(t: term_t; a: atom_t): CBool {.importc.}

## 🗹: Increment reference count of atom by one. `PL_new_atom()` does this automatically.
proc PL_register_atom*(a: atom_t) {.importc.}

## 🗹: Decrement reference count of atom. If reference count drops below zero, an assertion error is raised.
proc PL_unregister_atom*(a: atom_t) {.importc.}

# character...

# 🞎:
proc PL_atom_chars*(a: atom_t): cstring {.importc.}

# 🞎:
proc PL_get_atom_chars*(t: term_t; a: ptr cstring): CBool {.importc.}

# 🞎:
proc PL_unify_atom_chars*(t: term_t; chars: cstring): CBool {.importc.}

# 🞎:
proc PL_put_atom_chars*(t: term_t; chars: cstring): CBool {.importc.}

# character with length...

# 🞎:
proc PL_atom_nchars*(a: atom_t; len: ptr uint): cstring {.importc.}

# 🞎:
proc PL_get_atom_nchars*(t: term_t; len: ptr uint; a: ptr cstring): CBool {.importc.}

# 🞎:
proc PL_unify_atom_nchars*(t: term_t; l: uint; s: cstring): CBool {.importc.}

# 🞎:
proc PL_put_atom_nchars*(t: term_t; l: uint; chars: cstring): CBool {.importc.}

# 🞎:
proc PL_new_atom_nchars*(len: uint; s: cstring): atom_t {.importc.}

# locale-specific characters...

# 🞎:
proc PL_new_atom_mbchars*(rep: cint; len: uint; s: cstring): atom_t {.importc.}

###########
## Value ##
###########

type term_value_t* {.union, bycopy, importc.} = object
  i*: int64            ## PL_INTEGER
  f*: cdouble          ## PL_FLOAT
  s*: cstring          ## PL_STRING
  a*: atom_t           ## PL_ATOM
  t*: Type_SWIPrologh1 ## PL_ATOM

# 🞎:
proc PL_get_term_value*(t: term_t; v: ptr term_value_t): CBool {.importc.}

##############
## Variable ##
##############

## 🗹: Discover if term is a variable.
proc PL_is_variable*(t: term_t): CBool {.importc.}

# 🞎:
proc PL_put_variable*(t: term_t): CBool {.importc.}

# attributed...

# 🞎:
proc PL_get_attr*(v, a: term_t): CBool {.importc.}

# 🞎:
proc PL_is_attvar*(t: term_t): CBool {.importc.}

############
## String ##
############

# 🞎:
proc PL_is_string*(t: term_t): CBool {.importc.}

# 🞎:
proc PL_utf8_strlen*(s: cstring; len: uint): uint {.importc.}

# 🞎:
proc PL_unify_string_chars*(t: term_t; chars: cstring): CBool {.importc.}

# 🞎:
proc PL_put_string_chars*(t: term_t; chars: cstring): CBool {.importc.}

# 🞎:
proc PL_quote*(chr: cint; data: cstring): cstring {.importc.}

# string with length...

# 🞎:
proc PL_unify_string_nchars*(t: term_t; len: uint; chars: cstring): CBool {.importc.}

# 🞎:
proc PL_put_string_nchars*(t: term_t; len: uint; chars: cstring): CBool {.importc.}

# buffer mark...

type buf_mark_t* {.importc.} = culong

const
  BUF_DISCARDABLE* = 0x00000000
  BUF_STACK* = 0x00010000
  BUF_MALLOC* = 0x00020000
  BUF_ALLOW_STACK* = 0x00040000
  BUF_RING* = BUF_STACK

# 🞎:
proc PL_release_string_buffers_from_mark*(mark: buf_mark_t) {.importc.}

# 🞎:
proc PL_mark_string_buffers*(mark: ptr buf_mark_t) {.importc.}

# encoding...

const
  REP_ISO_LATIN_1* = 0x00000000
  REP_UTF8* = 0x00100000
  REP_MB* = 0x00200000
  REP_FN* = REP_MB

# 🞎:
proc PL_cvt_encoding*(): cint {.importc.}

# 🞎:
proc PL_cvt_set_encoding*(enc: cint): cint {.importc.}

# 🞎:
proc SP_set_state*(state: cint) {.importc.}

# 🞎:
proc SP_get_state*(): cint {.importc.}

###############
## Character ##
###############

# 🞎:
proc PL_get_chars*(t: term_t; s: ptr cstring; flags: cuint): CBool {.importc.}

# 🞎:
proc PL_get_char_ex*(t: term_t; p: ptr cint; eof: cint): CBool {.importc.}

# 🞎:
proc PL_unify_chars*(t: term_t; flags: cint; len: uint; s: cstring): CBool {.importc.}

# 🞎:
proc PL_put_chars*(t: term_t; flags: cint; len: cint; chars: cstring): CBool {.importc.}

# characters with length...

# 🞎:
proc PL_get_nchars*(t: term_t; len: ptr uint; s: ptr cstring; flags: cuint): CBool {.importc.}

# 🞎:
proc PL_put_term_from_chars*(t: term_t; flags: cint; len: uint; s: cstring): CBool {.importc.}

# wide characters...

when defined(cpp):
  # http://www.cplusplus.com/reference/cwchar/wchar_t/
  # In C-+, wchar_t is a distinct fundamental type (and thus it is not defined in <cwchar> nor any other header).
  type wchar_t* {.importc.} = object
else:
  type wchar_t* {.importc, header: "stddef.h".} = object

type pl_wchar_t* {.importc.} = wchar_t

# wide characters...

# 🞎:
proc PL_new_atom_wchars*(len: uint; s: ptr pl_wchar_t): atom_t {.importc.}

# 🞎:
proc PL_atom_wchars*(a: atom_t; len: ptr uint): ptr wchar_t {.importc.}

# 🞎:
proc PL_get_wchars*(l: term_t; length: ptr uint; s: ptr ptr pl_wchar_t; flags: cuint): CBool {.importc.}

# 🞎:
proc PL_unify_wchars_diff*(t, tail: term_t; kind: cint; len: uint; s: ptr pl_wchar_t): CBool {.importc.}

# 🞎:
proc PL_unify_wchars*(t: term_t; kind: cint; len: uint; s: ptr pl_wchar_t): CBool {.importc.}

# 🞎:
proc PL_wchars_to_term*(chars: ptr pl_wchar_t; term: term_t): CBool {.importc.}

#############
## Integer ##
#############

# 🞎:
proc PL_get_integer*(t: term_t; i: ptr cint): CBool {.importc.}

# 🞎:
proc PL_get_integer_ex*(t: term_t; i: ptr cint): CBool {.importc.}

# 🞎:
proc PL_is_integer*(t: term_t): CBool {.importc.}

# 🞎:
proc PL_unify_integer*(t: term_t; n: ptr int): CBool {.importc.}

# 🞎:
proc PL_put_integer*(t: term_t; i: clong): CBool {.importc.}

# rational...

# 🞎:
proc PL_is_rational*(t: term_t): CBool {.importc.}

# long...

# 🞎:
proc PL_get_long*(t: term_t; i: ptr clong): CBool {.importc.}

# 🞎:
proc PL_get_long_ex*(t: term_t; i: ptr clong): CBool {.importc.}

# 64-bit integer...

# 🞎:
proc PL_get_int64*(t: term_t; i: PInt64): CBool {.importc.}

# 🞎:
proc PL_get_int64_ex*(t: term_t; i: PInt64): CBool {.importc.}

# 🞎:
proc PL_put_int64*(t: term_t; i: int64): CBool {.importc.}

# 🞎:
proc PL_unify_int64*(t: term_t; value: int64): CBool {.importc.}

# unsigned...

# 🞎:
proc PL_get_size_ex*(t: term_t; i: ptr uint): CBool {.importc.}

# 🞎:
proc PL_unify_uint64*(t: term_t; value: uint64): CBool {.importc.}

# 🞎:
proc PL_put_uint64*(t: term_t; i: uint64): CBool {.importc.}

###########
## Float ##
###########

# 🞎:
proc PL_get_float*(t: term_t; f: ptr cdouble): CBool {.importc.}

# 🞎:
proc PL_get_float_ex*(t: term_t; f: ptr cdouble): CBool {.importc.}

# 🞎:
proc PL_is_float*(t: term_t): CBool {.importc.}

# 🞎:
proc PL_unify_float*(t: term_t; f: cdouble): CBool {.importc.}

# 🞎:
proc PL_put_float*(t: term_t; f: cdouble): CBool {.importc.}

############
## Number ##
############

# 🞎:
proc PL_is_number*(t: term_t): CBool {.importc.}

#############
## Pointer ##
#############

# 🞎:
proc PL_get_pointer*(t: term_t; point: ptr pointer): CBool {.importc.}

# 🞎:
proc PL_get_pointer_ex*(t: term_t; addrp: ptr pointer): CBool {.importc.}

# 🞎:
proc PL_unify_pointer*(t: term_t; point: pointer): CBool {.importc.}

# 🞎:
proc PL_put_pointer*(t: term_t; point: pointer): CBool {.importc.}

# integer pointer...

# 🞎:
proc PL_get_intptr*(t: term_t; i: ptr ptr int): CBool {.importc.}

# 🞎:
proc PL_get_intptr_ex*(t: term_t; i: ptr ptr int): CBool {.importc.}

##########
## Bool ##
##########

# 🞎:
proc PL_get_bool*(t: term_t; value: ptr cint): CBool {.importc.}

# 🞎:
proc PL_get_bool_ex*(t: term_t; i: ptr cint): CBool {.importc.}

# 🞎:
proc PL_unify_bool_ex*(t: term_t; val: cint): CBool {.importc.}

# 🞎:
proc PL_unify_bool*(t: term_t; n: cint): CBool {.importc.}

# 🞎:
proc PL_put_bool*(t: term_t; val: cint): CBool {.importc.}

#############
## Functor ##
#############

#[

Functor: combination of name and arity of a compound term.

e.g. the term `foo(a, b, c)` is said to be a term belonging to the functor `foo/3`. `foo/0` is used to refer to the atom
`foo`.
]#

type functor_t* {.importc.} = culong

const PL_ARITY_AS_SIZE* = 1

# 🞎:
proc PL_get_functor*(t: term_t; f: ptr functor_t): CBool {.importc.}

# 🞎:
proc PL_is_functor*(t: term_t; f: functor_t): CBool {.importc.}

# 🞎:
proc PL_is_callable*(t: term_t): CBool {.importc.}

# 🞎:
proc PL_functor_name*(f: functor_t): atom_t {.importc.}

# 🞎:
proc PL_new_functor*(f: atom_t; a: cint): functor_t {.importc.}

# 🞎:
proc PL_new_functor_sz*(f: atom_t; a: uint): functor_t {.importc.}

# 🞎:
proc PL_unify_functor*(t: term_t; f: functor_t): CBool {.importc.}

# 🞎:
proc PL_cons_functor*(h: term_t; f: functor_t): CBool {.importc, varargs.}

# 🞎:
proc PL_cons_functor_v*(h: term_t; fd: functor_t; a0: term_t): CBool {.importc.}

# 🞎:
proc PL_put_functor*(t: term_t; functor: functor_t): CBool {.importc.}

#[

Arity: argument count (= number of arguments) of a compound term.

]#

## 🗹: Get arity of the given functor.
proc PL_functor_arity*(f: functor_t): cint {.importc.}

## 🗹: Get arity of the given functor.
proc PL_functor_arity_sz*(f: functor_t): uint {.importc.}

# 🞎:
proc PL_get_name_arity*(t: term_t; name: ptr atom_t; arity: ptr cint): CBool {.importc.}

# 🞎:
proc PL_get_name_arity_sz*(t: term_t; name: ptr atom_t; arity: ptr uint): CBool {.importc.}

############
## Module ##
############

#[

Module: collection of predicates.

- each module defines a name-space for predicates
- built-in predicates are accessible from all modules.
- predicates can be published (exported) and imported to make their definition available to other modules.

]#

type module_t* {.importc.} = pointer # prolog module

# 🞎:
proc PL_get_module*(t: term_t; module: ptr module_t): CBool {.importc.}

# 🞎:
proc PL_module_name*(module: module_t): atom_t {.importc.}

# 🞎:
proc PL_context*(): module_t {.importc.}

# 🞎:
proc PL_new_module*(name: atom_t): module_t {.importc.}

# 🞎:
proc PL_strip_module*(`in`: term_t; m: ptr module_t; `out`: term_t): CBool {.importc.}

# Predicate...

type predicate_t* {.importc.} = pointer

# 🞎:
proc PL_pred*(f: functor_t; m: module_t): predicate_t {.importc.}

# 🞎:
proc PL_predicate*(name: cstring; arity: cint; module: cstring): predicate_t {.importc.}

# 🞎:
proc PL_predicate_info*(pred: predicate_t; name: ptr atom_t; arity: ptr uint; module: ptr module_t): cint {.importc.}

#[

Arguments: terms that appear in a compound term.

`A1` and `a2` are the first and second arguments of the term `myterm(A1, a2)`.

]#

## 🗹: Assign term reference `a` to argument of `t` at `index` (between 1 and arity).
proc PL_get_arg*(index: cint; t, a: term_t): CBool {.importc.}

## 🗹: Assign term reference `a` to argument of `t` at `index` (between 1 and arity).
proc PL_get_arg_sz*(index: uint; t, a: term_t): CBool {.importc.}

## 🗹: Unify argument of `t` at `index` (between 1 and arity) to term reference `a`.
proc PL_unify_arg*(index: cint; t, a: term_t): CBool {.importc.}

## 🗹: Unify argument of `t` at `index` (between 1 and arity) to term reference `a`.
proc PL_unify_arg_sz*(index: uint; t, a: term_t): CBool {.importc.}

#[

Compound [term]: `name` followed by `N` arguments, each of which are terms. `N` is called the arity of the term.

Also called structure.

]#

# 🞎:
proc PL_get_compound_name_arity*(t: term_t; name: ptr atom_t; arity: ptr cint): CBool {.importc.}

# 🞎:
proc PL_get_compound_name_arity_sz*(t: term_t; name: ptr atom_t; arity: ptr uint): CBool {.importc.}

# 🞎:
proc PL_is_compound*(t: term_t): CBool {.importc.}

# 🞎:
proc PL_same_compound*(t1, t2: term_t): CBool {.importc.}

# 🞎:
proc PL_unify_compound*(t: term_t; f: functor_t): CBool {.importc.}

##########
## List ##
##########

const PL_DIFF_LIST* = 0x01000000

# 🞎:
proc PL_get_list*(l, h, t: term_t): CBool {.importc.}

# 🞎:
proc PL_get_list_ex*(l, h, t: term_t): CBool {.importc.}

# 🞎:
proc PL_get_head*(l, h: term_t): CBool {.importc.}

# 🞎:
proc PL_get_tail*(l, t: term_t): CBool {.importc.}

# 🞎:
proc PL_skip_list*(list, tail: term_t; len: ptr uint): cint {.importc.}

# 🞎:
proc PL_is_list*(t: term_t): CBool {.importc.}

# 🞎:
proc PL_is_pair*(t: term_t): CBool {.importc.}

# 🞎:
proc PL_unify_list*(l, h, t: term_t): CBool {.importc.}

# 🞎:
proc PL_unify_list_ex*(l, h, t: term_t): CBool {.importc.}

# 🞎:
proc PL_cons_list*(l, h, t: term_t): CBool {.importc.}

# 🞎:
proc PL_put_list*(l: term_t): CBool {.importc.}

# Unicode code point list...

# 🞎:
proc PL_put_list_codes*(t: term_t; chars: cstring): CBool {.importc.}

# 🞎:
proc PL_unify_list_codes*(t: term_t; chars: cstring): CBool {.importc.}

# unicode code point list with length...

# 🞎:
proc PL_unify_list_ncodes*(t: term_t; l: uint; s: cstring): CBool {.importc.}

# 🞎:
proc PL_put_list_ncodes*(t: term_t; l: uint; chars: cstring): CBool {.importc.}

# Character list...

# 🞎:
proc PL_get_list_chars*(l: term_t; s: ptr cstring; flags: cuint): CBool {.importc.}

# 🞎:
proc PL_unify_list_chars*(t: term_t; chars: cstring): CBool {.importc.}

# 🞎:
proc PL_put_list_chars*(t: term_t; chars: cstring): CBool {.importc.}

# character list with length...

# 🞎:
proc PL_get_list_nchars*(l: term_t; len: ptr uint; s: ptr cstring; flags: cuint): CBool {.importc.}
# 🞎:
proc PL_unify_list_nchars*(t: term_t; l: uint; s: cstring): CBool {.importc.}
# 🞎:
proc PL_put_list_nchars*(t: term_t; l: uint; chars: cstring): CBool {.importc.}

##########
## Dict ##
##########

## 🗹: Get value of key from dict.
proc PL_get_dict_key*(key: atom_t; dict: term_t; value: term_t): CBool {.importc.}

## 🗹: Discover if term is a dict.
proc PL_is_dict*(t: term_t): CBool {.importc.}

## 🗹: Create dict from tag and vector of atom-value pairs.
proc PL_put_dict*(t: term_t; tag: atom_t; len: uint; keys: ptr UncheckedArray[atom_t]; values: term_t): CBool {.importc.}

##########
## Blob ##
##########

type
  PL_blob_t* {.bycopy, importc: "struct PL_blob_t".} = object
    magic*, flags*: ptr uint # PL_BLOB_*
    name*: cstring # name of the type
    release*: proc(a: atom_t): cint {.cdecl.}
    compare*: proc(a: atom_t; b: atom_t): cint {.cdecl.}
    write*: proc(s: pointer; a: atom_t; flags: cint): cint {.cdecl.}
    acquire*: proc(a: atom_t) {.cdecl.}
    save*: proc(a: atom_t; a2: pointer): cint {.cdecl.}
    load*: proc(s: pointer): atom_t {.cdecl.}
    padding*: uint # Required 0-padding
    ## private
    ## for future extension
    reserved*: array[9, pointer]
    ## Already registered?
    registered*: cint
    ## Rank for ordering atoms
    rank*: cint
    ## next in registered type-chain
    next*: PPL_blob_t
    ## Name as atom
    atom_name*: atom_t

  PPL_blob_t* = ptr PL_blob_t

const
  PL_BLOB_MAGIC_B* = 0x75293A00
  PL_BLOB_VERSION* = 1
  PL_BLOB_MAGIC* = (PL_BLOB_MAGIC_B or typeof(PL_BLOB_MAGIC_B)(PL_BLOB_VERSION))
  PL_BLOB_UNIQUE* = 0x00000001
  PL_BLOB_TEXT* = 0x00000002
  PL_BLOB_NOCOPY* = 0x00000004
  PL_BLOB_WCHAR* = 0x00000008

## 🗹: If term is a blob or atom, get its data and type.
proc PL_get_blob*(t: term_t; blob: ptr pointer; len: ptr uint; kind: ptr PPL_blob_t): CBool {.importc.}

## 🗹: Get the data and type associated with a blob.
proc PL_blob_data*(a: atom_t; len: ptr uint; kind: ptr PPL_blob_t): pointer {.importc.}

## 🗹: Succeeds if term `t` refers to a blob, in which case `kind` is filled with the type of the blob.
proc PL_is_blob*(t: term_t; kind: ptr PPL_blob_t): CBool {.importc.}

## 🗹: Unify term to new blob constructed from given data and assigned the given type.
proc PL_unify_blob*(t: term_t; blob: pointer; len: uint; kind: PPL_blob_t): CBool {.importc.}

## 🗹: Store the described blob in term.
proc PL_put_blob*(t: term_t; blob: pointer; len: uint; kind: PPL_blob_t): CBool {.importc.}

# blob type...

## 🗹: Link the blob type to the registered type.
proc PL_register_blob_type*(kind: PPL_blob_t) {.importc.}

## 🗹: Query the blob type by name.
proc PL_find_blob_type*(name: cstring): PPL_blob_t {.importc.}

## 🗹: Unlink the blob type from the registered type.
proc PL_unregister_blob_type*(kind: PPL_blob_t): CBool {.importc.}

#########
## Nil ##
#########

# 🞎:
proc PL_get_nil*(l: term_t): CBool {.importc.}

# 🞎:
proc PL_get_nil_ex*(l: term_t): CBool {.importc.}

# 🞎:
proc PL_new_nil_ref*(): term_t {.importc.}

# 🞎:
proc PL_put_nil*(l: term_t): CBool {.importc.}

# 🞎:
proc PL_unify_nil*(l: term_t): CBool {.importc.}

# 🞎:
proc PL_unify_nil_ex*(l: term_t): CBool {.importc.}

############
## Atomic ##
############

type PL_atomic_t* {.importc.} = ptr uint ## same as word

# 🞎:
proc PL_get_atomic*(t: term_t): PL_atomic_t {.importc: "_PL_get_atomic".}

# 🞎:
proc PL_is_atomic*(t: term_t): cint {.importc.}

# 🞎:
proc PL_unify_atomic*(t: term_t; a: PL_atomic_t): cint {.importc: "_PL_unify_atomic".}

# 🞎:
proc PL_put_atomic*(t: term_t; a: PL_atomic_t) {.importc: "_PL_put_atomic".}

###########
## Query ##
###########

type
  qid_t* {.importc.} = pointer ## Query identifier

  # Extended status codes...
  Query* {.size: sizeof(distinct cint).} = enum
    queryException = -1 ## 🗹: PL_S_EXCEPTION: Exception available...
    queryFalse = 0      ## 🗹: PL_S_FALSE: Query failed...
    queryTrue = 1       ## 🗹: PL_S_TRUE: Query succeeded with choicepoint...
    queryLast = 2       ## 🗹: PL_S_LAST: Query succeeded without choicepoint...

const
  # Query flags...
  ## 🗹: Normal operation. Starts tracer to debug error.
  PL_Q_NORMAL* = 0x00000002
  ## 🗹: Switch off the debugger while executing the goal.
  PL_Q_NODEBUG* = 0x00000004
  ## 🗹: If exception raised, don't report it, but make it available for `PL_exception()`
  PL_Q_CATCH_EXCEPTION* = 0x00000008
  ## 🗹: Like PL_Q_CATCH_EXCEPTION, but do not toss the exception while calling `PL_close_query()`
  PL_Q_PASS_EXCEPTION* = 0x00000010
  ## 🗹: Enable engine-based coroutining.
  PL_Q_ALLOW_YIELD* = 0x00000020
  ## 🗹: Make PL_next_solution() return extended status codes below...
  PL_Q_EXT_STATUS* = 0x00000040

# call...

## 🗹: Call term once.
proc PL_call*(t: term_t; m: module_t): CBool {.importc.}

## 🗹: Combines `PL_open_query()`, `PL_next_solution()`, and `PL_cut_query()`, generating one solution.
proc PL_call_predicate*(m: module_t; debug: cint; pred: predicate_t; t0: term_t): CBool {.importc.}

# query...

## 🗹: Open one Prolog query.
proc PL_open_query*(m: module_t; flags: cint; pred: predicate_t; t0: term_t): qid_t {.importc.}

## 🗹: Generate next solution for current query
proc PL_next_solution*(qid: qid_t): cint {.importc.}

## 🗹: Get query id of current query or 0 if current thread is not executing any queries.
proc PL_current_query*(): qid_t {.importc.}

## 🗹: Closes the query, but keeps any data created by the query.
proc PL_cut_query*(qid: qid_t): CBool {.importc.}

## 🗹: Closes the query and tosses any data created by the query.
proc PL_close_query*(qid: qid_t): CBool {.importc.}

## 🗹: Yield control from this engine. `Calling PL_next_solution()` resumes.
proc PL_yielded*(qid: qid_t): term_t {.importc.}  # Engine-based coroutining

# assert...

const
  # Add the new clause as last. Calls `assertz/1`. This macros is defined as 0 and thus the default.
  PL_ASSERTZ* = 0x00000000
  # Add the new clause as first. Calls `asserta/1`.
  PL_ASSERTA* = 0x00000001

  # If predicate is not defined, create it as thread-local.
  PL_CREATE_THREAD_LOCAL* = 0x00000010
  # If predicate is not defined, create it as incremental.
  PL_CREATE_INCREMENTAL* = 0x00000020

## 🗹: Direct access to `asserta/1` and `assertz/1` by asserting `t` into the database in the module `m`.
proc PL_assert*(t: term_t; m: module_t; flags: cint): CBool {.importc.}

###########
## Error ##
###########

# exception...

# 🞎:
proc PL_exception*(status: cint): term_t {.importc.}

# 🞎:
proc PL_exception*(qid: qid_t): term_t {.importc.}

# 🞎:
proc PL_raise_exception*(exception: term_t): cint {.importc.}

# 🞎:
proc PL_throw*(exception: term_t): cint {.importc.}

# 🞎:
proc PL_clear_exception*() {.importc.}

# specific error...

# 🞎:
proc PL_warning*(fmt: cstring): cint {.importc, varargs.}

# 🞎:
proc PL_fatal_error*(fmt: cstring) {.importc, varargs.}

# 🞎:
proc PL_instantiation_error*(culprit: term_t): cint {.importc.}

# 🞎:
proc PL_uninstantiation_error*(culprit: term_t): cint {.importc.}

# 🞎:
proc PL_representation_error*(resource: cstring): cint {.importc.}

# 🞎:
proc PL_type_error*(expected: cstring; culprit: term_t): cint {.importc.}

# 🞎:
proc PL_domain_error*(expected: cstring; culprit: term_t): cint {.importc.}

# 🞎:
proc PL_existence_error*(kind: cstring; culprit: term_t): cint {.importc.}

# 🞎:
proc PL_permission_error*(operation, kind: cstring; culprit: term_t): cint {.importc.}

# 🞎:
proc PL_resource_error*(resource: cstring): cint {.importc.}

# 🞎:
proc PL_syntax_error*(msg: cstring; `in`: pointer): cint {.importc.}

# 🞎:
proc PL_thread_raise*(tid: cint; sig: cint): cint {.importc.}

###########################
## Foreign Context Frame ##
############################

type PL_fid_t* {.importc.} = culong ## Foreign frame.

## 🗹: Create a foreign frame to enable SWI-Prolog garbage collection.
proc PL_open_foreign_frame*(): PL_fid_t {.importc.}

## 🗹: Do Prolog and discard all data made within its scope (include bindings) without closing the frame.
proc PL_rewind_foreign_frame*(cid: PL_fid_t) {.importc.}

## 🗹: Open foreign frame, do Prolog, and discard all term references madein its scope but keep data on close.
proc PL_close_foreign_frame*(cid: PL_fid_t) {.importc.}

## 🗹: Open foreign frame, do Prolog, and discard all data made in its scope (include bindings) on close.
proc PL_discard_foreign_frame*(cid: PL_fid_t) {.importc.}

######################
## Startup/Shutdown ##
######################

## 🗹: Initialize SWI-Prolog engine.
proc PL_initialise*(argc: cint; argv: cstring_array): CBool {.importc.}

## 🗹: Test whether the Prolog engine is already initialized.
proc PL_is_initialised*(argc: ptr cint; argv: ptr ptr cstring): CBool {.importc.}

## 🗹: Load saved program state. MUST BE CALLED BEFORE `PL_initialise`.
proc PL_set_resource_db_mem*(data: ptr uint8; size: uint): cint {.importc.}

## 🗹: Run goal of `-t toplevel` CLI switch pased to `swipl_lib` if specified or `prolog/0` if unspecified.
proc PL_toplevel*(): cint {.importc.}

## 🗹: Cleanup and shutdown SWI-Prolog engine.
proc PL_cleanup*(status: cint): CBool {.importc.}

## 🗹: Cleanup and shutdown SWI-Prolog engine unless `PL_cleanup` runs into issues.
proc PL_halt*(status: cint): CBool {.importc.}

when defined(windows):
  ## 🗹: Wide character version of `PL_initialise()`. Used in Windows.
  proc PL_winitialise*(argc: cint; argv: ptr ptr wchar_t): CBool {.importc.}

#######################
## Recorded Database ##
#######################

# internal database...

## 🗹: Prolog internal recorded term.
type record_t* {.importc.} = pointer

## 🗹: Record internal term into the Prolog database.
proc PL_record*(term: term_t): record_t {.importc.}

## 🗹: Duplicate internal record.
proc PL_duplicate_record*(r: record_t): record_t {.importc.}

## 🗹: Copy recorded internal term back to Prolog database.
proc PL_recorded*(record: record_t; term: term_t): cint {.importc.}

## 🗹: Remove recorded internal term from Prolog database, reclaiming all allocated memory resources.
proc PL_erase*(record: record_t) {.importc.}

# External record...

## 🗹: Record external term into the Prolog database.
proc PL_record_external*(t: term_t; size: ptr uint): cstring {.importc.}

## 🗹: Copy recorded external term back to the Prolog stack.
proc PL_recorded_external*(rec: cstring; term: term_t): cint {.importc.}

## 🗹: Remove recorded external term from Prolog database, reclaiming all allocated memory resources.
proc PL_erase_external*(rec: cstring): cint {.importc.}

#################
## Environment ##
#################

const
  PL_QUERY_ARGC* = 1
  PL_QUERY_ARGV* = 2
  PL_QUERY_GETC* = 5
  PL_QUERY_MAX_INTEGER* = 6
  PL_QUERY_MIN_INTEGER* = 7
  PL_QUERY_MAX_TAGGED_INT* = 8
  PL_QUERY_MIN_TAGGED_INT* = 9
  PL_QUERY_VERSION* = 10
  PL_QUERY_MAX_THREADS* = 11
  PL_QUERY_ENCODING* = 12
  PL_QUERY_USER_CPU* = 13
  PL_QUERY_HALTING* = 14

  FF_READONLY* = 0x00001000
  FF_KEEP* = 0x00002000
  FF_NOCREATE* = 0x00004000
  FF_FORCE* = 0x00008000
  FF_MASK* = 0x0000F000

# 🞎:
proc PL_query*(a1: cint): ptr int {.importc.}

## 🗹: Set flag where `name` is the name of the flag, and the flag setting. Can be called before `PL_initialise()`.
proc PL_set_prolog_flag*(name: cstring; kind: cint): CBool {.importc, varargs.}

# 🞎:
proc PL_current_prolog_flag*(name: atom_t; kind: cint; point: pointer): cint {.importc.}

#############
## Version ##
#############

const
  PLVERSION_NUMBER* = 80203
  PLVERSION_TAG* = ""

  PL_FLI_VERSION* = 2
  PL_REC_VERSION* = 3

  PL_QLF_LOADVERSION* = 67
  PL_QLF_VERSION* = 67

  PL_VERSION_SYSTEM* = 1
  PL_VERSION_FLI* = 2
  PL_VERSION_REC* = 3
  PL_VERSION_QLF* = 4
  PL_VERSION_QLF_LOAD* = 5
  PL_VERSION_VM* = 6
  PL_VERSION_BUILT_IN* = 7

# 🞎:
proc PL_version*(which: cint): cuint {.importc.}

############
## Thread ##
############

type PL_thread_attr_t* {.bycopy, importc.} = object
  ## Total stack limit (bytes)
  stack_limit*: uint
  ## Total tabling space limit (bytes)
  table_space*: uint
  ## alias name
  alias*: cstring
  ## cancel function
  cancel*: proc(id: cint): rc_cancel {.cdecl.}
  ## PL_THREAD_* flags
  flags*: ptr int
  ## Max size of associated queue
  max_queue_size*: uint
  ## reserved for extensions
  reserved*: array[3, pointer]

const
  PL_THREAD_NO_DEBUG* = 0x00000001
  PL_THREAD_NOT_DETACHED* = 0x00000002
  PL_THREAD_CANCEL_FAILED* = ((0)).rc_cancel  ## failed to cancel; try abort
  PL_THREAD_CANCEL_JOINED* = ((1)).rc_cancel  ## cancelled and joined
  PL_THREAD_CANCEL_MUST_JOIN* = (PL_THREAD_CANCEL_JOINED + 1)  ## cancelled, must thread

## 🗹: Get identifier of the engine.
proc PL_thread_self*(): cint {.importc.}

## 🗹: Create new Prolog engine in the calling thread.
proc PL_thread_attach_engine*(attr: ptr PL_thread_attr_t): cint {.importc.} ## Locks alias

## 🗹: Destroy the Prolog engine in the calling thread.
proc PL_thread_destroy_engine*(): cint {.importc.}

## 🗹: Register callback called as Prolog engine is destroyed.
proc PL_thread_at_exit*(function: proc(a1: pointer) {.cdecl.};closure: pointer; global: cint): cint {.importc.}

# 🞎:
proc PL_unify_thread_id*(t: term_t; i: cint): cint {.importc.}  ## Prolog thread id (-1 if none)

# 🞎:
proc PL_get_thread_id_ex*(t: term_t; idp: ptr cint): cint {.importc.}  ## Prolog thread id (-1 if none)

# 🞎:
proc PL_get_thread_alias*(tid: cint; alias: ptr atom_t): cint {.importc.} ## Locks alias

############
## Engine ##
############

type PL_engine_t* {.importc.} = pointer

const
  PL_ENGINE_MAIN* = (cast[PL_engine_t](0x00000001))
  PL_ENGINE_CURRENT* = (cast[PL_engine_t](0x00000002))
  PL_ENGINE_SET* = 0
  PL_ENGINE_INVAL* = 2
  PL_ENGINE_INUSE* = 3

## 🗹: Create a new Prolog engine in thread pool.
proc PL_create_engine*(attributes: ptr PL_thread_attr_t): PL_engine_t {.importc.}

## 🗹: Destroy engine in thread pool.
proc PL_set_engine*(engine: PL_engine_t; old: ptr PL_engine_t): cint {.importc.}

# 🞎:
proc PL_destroy_engine*(engine: PL_engine_t): cint {.importc.}

###########
## Debug ##
###########

type
  pl_context_t* {.bycopy, importc: "struct pl_context_t".} = object
    ## Engine
    ld*: PL_engine_t
    ## Current query
    qf*: QueryFrame
    ## Current localframe
    fr*: LocalFrame
    ## Code pointer
    pc*: Code
    ## Reserved for extensions
    reserved*: array[10, pointer]

  QueryFrame* {.importc.} = pointer

  LocalFrame* {.importc.} = pointer

  Code* {.importc.} = pointer

## 🗹: Enable debug topic (listed in in `src/pl-debug.h`).
proc PL_prolog_debug*(topic: cstring): CBool {.importc.}

# 🞎:
proc PL_get_context*(c: ptr pl_context_t; thead_id: cint): cint {.importc.}

# 🞎:
proc PL_step_context*(c: ptr pl_context_t): cint {.importc.}

# 🞎:
proc PL_describe_context*(c: ptr pl_context_t; buf: cstring; len: uint): cint {.importc.}

## 🗹: Disable debug topic (listed in in `src/pl-debug.h`).
proc PL_prolog_nodebug*(topic: cstring): CBool {.importc.}

#############
## Profile ##
#############

type PL_prof_type_t* {.bycopy, importc.} = object
  ## 🗹: implementation -> Prolog
  unify*: proc(t: term_t; handle: pointer): cint {.cdecl.}
  ## 🗹: Prolog -> implementation
  get*: proc(t: term_t; handle: ptr pointer): cint {.cdecl.}
  ## 🗹: (de)activate
  activate*: proc(active: cint) {.cdecl.}
  ## 🗹: PROFTYPE_MAGIC
  magic*: ptr int

# 🞎:
proc PL_prof_call*(handle: pointer; kind: ptr PL_prof_type_t): pointer {.importc.}

# 🞎:
proc PL_prof_exit*(node: pointer) {.importc.}

# 🞎:
proc PL_register_profile_type*(kind: ptr PL_prof_type_t): cint {.importc.}

## 🗹: Shutdown profiler.
proc PL_cleanup_fork*() {.importc.}

#########
## FFI ##
#########

# Foreign functions...

type
  control_t* {.importc.} = pointer  # non-deterministic control arg
  foreign_t* {.importc.} = ptr uint  # return type of foreign functions
  pl_function_t* {.importc.} = proc(): foreign_t {.cdecl, varargs.}

  FFIFlag* {.size: sizeof(distinct cint).} = enum
    ffiNOTRACE = (0x00000001).cint
    ffiTRANSPARENT = (0x00000002).cint
    ffiNONDET = (0x00000004).cint
    ffiVARARGS = (0x00000008).cint
    ffiCREF = (0x00000010).cint
    ffiISO = (0x00000020).cint
    ffiMETA = (0x00000040).cint

const
  PL_FA_NOTRACE* = (0x00000001)
  PL_FA_TRANSPARENT* = (0x00000002)
  PL_FA_NONDETERMINISTIC* = (0x00000004)
  PL_FA_VARARGS* = (0x00000008)
  PL_FA_CREF* = (0x00000010)
  PL_FA_ISO* = (0x00000020)
  PL_FA_META* = (0x00000040)

## 🗹: Register function implementing a Prolog predicate.
proc PL_register_foreign*(name: cstring; arity: cint; fn: pl_function_t; flags: cint): CBool {.importc, varargs.}

## 🗹: Register function implementing a Prolog predicate in a specific Prolog module.
proc PL_register_foreign_in_module*(
  module, name: cstring;
  arity: cint;
  fn: pl_function_t;
  flags: cint,
): CBool {.importc, varargs.}

# extension...

type
  PL_extension* {.bycopy, importc: "struct PL_extension".} = object
    ## Name of the predicate
    predicate_name*: cstring
    ## Arity of the predicate
    arity*: cshort
    ## Implementing functions
    function*: pl_function_t
    ## Or of PL_FA_...
    flags*: cshort

# 🞎:
proc PL_register_extensions*(e: ptr PL_extension) {.importc.}

# 🞎:
proc PL_register_extensions_in_module*(module: cstring; e: ptr PL_extension) {.importc.}

# 🞎:
proc PL_load_extensions*(e: ptr PL_extension) {.importc.}

# 🞎:
proc PL_license*(license: cstring; module: cstring) {.importc.}

# non-deterministic function...

const
  PL_FIRST_CALL* = (0)
  PL_CUTTED* = (1)
  PL_PRUNED* = (1)
  PL_REDO* = (2)

# 🞎:
proc PL_retry*(a1: ptr int): foreign_t {.importc: "_PL_retry".}

# 🞎:
proc PL_retry_address*(a1: pointer): foreign_t {.importc: "_PL_retry_address".}

# 🞎:
proc PL_foreign_control*(a1: control_t): cint {.importc.}

# 🞎:
proc PL_foreign_context*(a1: control_t): ptr int {.importc.}

# 🞎:
proc PL_foreign_context_address*(a1: control_t): pointer {.importc.}

# 🞎:
proc PL_foreign_context_predicate*(a1: control_t): predicate_t {.importc.}

##########
## Hook ##
##########

type
  PL_dispatch_hook_t* {.importc.} = proc(fd: cint): cint {.cdecl.}
  PL_abort_hook_t* {.importc.} = proc() {.cdecl.}
  PL_initialise_hook_t* {.importc.} = proc(argc: cint; argv: ptr cstring) {.cdecl.}
  PL_agc_hook_t* {.importc.} = proc(a: atom_t): cint {.cdecl.}

const
  PL_DISPATCH_INPUT* = 0
  PL_DISPATCH_TIMEOUT* = 1

# 🞎:
proc PL_dispatch_hook*(a1: PL_dispatch_hook_t): PL_dispatch_hook_t {.importc.}

# 🞎:
proc PL_abort_hook*(a1: PL_abort_hook_t) {.importc.}

# 🞎:
proc PL_initialise_hook*(a1: PL_initialise_hook_t) {.importc.}

# 🞎:
proc PL_abort_unhook*(a1: PL_abort_hook_t): cint {.importc.}

# 🞎:
proc PL_agc_hook*(a1: PL_agc_hook_t): PL_agc_hook_t {.importc.}

##############
## Filename ##
##############

const
  PL_FILE_ABSOLUTE* = 0x00000001
  PL_FILE_OSPATH* = 0x00000002
  PL_FILE_SEARCH* = 0x00000004
  PL_FILE_EXIST* = 0x00000008
  PL_FILE_READ* = 0x00000010
  PL_FILE_WRITE* = 0x00000020
  PL_FILE_EXECUTE* = 0x00000040
  PL_FILE_NOERRORS* = 0x00000080

# 🞎:
proc PL_get_file_name*(n: term_t; name: ptr cstring; flags: cint): cint {.importc.}

# 🞎:
proc PL_get_file_nameW*(n: term_t; name: ptr ptr wchar_t; flags: cint): cint {.importc.}

# 🞎:
proc PL_cwd*(buf: cstring; buflen: uint): cstring {.importc.}

# 🞎:
proc PL_changed_cwd*() {.importc.}  ## foreign code changed CWD

############
## Signal ##
############

type
  pl_sigaction* {.bycopy, importc: "struct pl_sigaction".} = object
    ## traditional C function
    sa_cfunction*: proc(a1: cint) {.cdecl.}
    ## call a predicate
    sa_predicate*: predicate_t
    ## additional flags
    sa_flags*: cint
    ## future extentions
    reserved*: array[2, pointer]

  pl_sigaction_t* {.importc.} = pl_sigaction

const
  PL_SIGSYNC* = 0x00010000
  PL_SIGNOFRAME* = 0x00020000

  PLSIG_THROW* = 0x00000002
  PLSIG_SYNCS* = 0x00000004
  PLSIG_NOFRAMES* = 0x00000008

# 🞎:
proc PL_signal*(sig: cint; fn: proc(a1: cint) {.cdecl.}) {.importc.}

# 🞎:
proc PL_sigaction*(sig: cint; act, old: ptr pl_sigaction_t): cint {.importc.}

# 🞎:
proc PL_interrupt*(sig: cint) {.importc.}

# 🞎:
proc PL_raise*(sig: cint): cint {.importc.}

# 🞎:
proc PL_handle_signals*(): cint {.importc.}

# 🞎:
proc PL_get_signum_ex*(sig: term_t; n: ptr cint): cint {.importc.}

############
## Action ##
############

const
  PL_ACTION_TRACE* = 1
  PL_ACTION_DEBUG* = 2
  PL_ACTION_BACKTRACE* = 3
  PL_ACTION_BREAK* = 4
  PL_ACTION_HALT* = 5
  PL_ACTION_ABORT* = 6
  PL_ACTION_WRITE* = 8
  PL_ACTION_FLUSH* = 9
  PL_ACTION_GUIAPP* = 10
  PL_ACTION_ATTACH_CONSOLE* = 11
  PL_GMP_SET_ALLOC_FUNCTIONS* = 12
  PL_ACTION_TRADITIONAL* = 13

  PL_BT_SAFE* = 0x00000001
  PL_BT_USER* = 0x00000002

# 🞎:
proc PL_action*(a1: cint): cint {.importc, varargs.}

# 🞎:
proc PL_on_halt*(a1: proc(a1: cint; a2: pointer): cint {.cdecl.}; a2: pointer) {.importc.}

# 🞎:
proc PL_exit_hook*(a1: proc(a1: cint; a2: pointer): cint {.cdecl.}; a2: pointer) {.importc.}

# 🞎:
proc PL_backtrace*(depth: cint; flags: cint) {.importc.}

# 🞎:
proc PL_backtrace_string*(depth: cint; flags: cint): cstring {.importc.}

# 🞎:
proc PL_check_data*(data: term_t): cint {.importc.}

# 🞎:
proc PL_check_stacks*(): cint {.importc.}

#######################
## Memory Management ##
#######################

# 🞎:
proc PL_malloc*(size: uint): pointer {.importc.}

# 🞎:
proc PL_malloc_atomic*(size: uint): pointer {.importc.}

# 🞎:
proc PL_malloc_uncollectable*(size: uint): pointer {.importc.}

# 🞎:
proc PL_malloc_atomic_uncollectable*(size: uint): pointer {.importc.}

# 🞎:
proc PL_realloc*(mem: pointer; size: uint): pointer {.importc.}

# 🞎:
proc PL_malloc_unmanaged*(size: uint): pointer {.importc.}

# 🞎:
proc PL_malloc_atomic_unmanaged*(size: uint): pointer {.importc.}

# 🞎:
proc PL_free*(mem: pointer) {.importc.}

# 🞎:
proc PL_linger*(mem: pointer): cint {.importc.}

#####################
## Dynamic Library ##
#####################

# 🞎:
proc PL_dlopen*(file: cstring; flags: cint): pointer {.importc.}

# 🞎:
proc PL_dlsym*(handle: pointer; symbol: cstring): pointer {.importc.}

# 🞎:
proc PL_dlclose*(handle: pointer): cint {.importc.}

# 🞎:
proc PL_dlerror*(): cstring {.importc.}

################
## Hash Table ##
################

type
  pl_hash_table {.importc.} = object
  pl_hash_table_enum {.importc.} = object
  hash_table_t* {.importc.} = ptr pl_hash_table
  hash_table_enum_t* {.importc.} = ptr pl_hash_table_enum

const
  PL_HT_NEW* = 0x00000001
  PL_HT_UPDATE* = 0x00000002

# 🞎:
proc PL_lookup_hash_table*(table: hash_table_t; key: pointer): pointer {.importc.}

# 🞎:
proc PL_new_hash_table*(size: cint; free_symbol: proc(n, v: pointer) {.cdecl.}): hash_table_t {.importc.}

# 🞎:
proc PL_new_hash_table_enum*(table: hash_table_t): hash_table_enum_t {.importc.}

# 🞎:
proc PL_add_hash_table*(table: hash_table_t; key, value: pointer; flags: cint): pointer {.importc.}

# 🞎:
proc PL_advance_hash_table_enum*(e: hash_table_enum_t; key, value: ptr pointer): cint {.importc.}

# 🞎:
proc PL_clear_hash_table*(table: hash_table_t): cint {.importc.}

# 🞎:
proc PL_del_hash_table*(table: hash_table_t; key: pointer): pointer {.importc.}

# 🞎:
proc PL_free_hash_table*(table: hash_table_t): cint {.importc.}

# 🞎:
proc PL_free_hash_table_enum*(e: hash_table_enum_t) {.importc.}

{.pop.} # header
{.pop.} # cdecl
