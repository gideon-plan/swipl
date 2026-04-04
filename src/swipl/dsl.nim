{.experimental: "strictFuncs".}
## SWI-Prolog term builder DSL.

import std/[macros, sets, strformat, strutils, sugar, tables]

import basis/code/throw

standard_pragmas()

# -----------------------------------------------------------------------
# Inline constants (from archive tool/so, code/ast, kind/literal)
# -----------------------------------------------------------------------

const
  BLANK* = ""
  COMMA* = ", "
  BOOL_NAME = ["true", "false"].toHashSet()
  XPR_KIND = nnkCallKinds + {nnkCurlyExpr}

template empty*(s: string): bool = s.len == 0
template full*(s: string): bool = s.len > 0

proc escape_quote*(s: string): string {.raises: [ValueError].} =
  "'" & s.replace("'", "\\'") & "'"

template first*[T](s: seq[T]): T = s[0]

# -----------------------------------------------------------------------
# Types
# -----------------------------------------------------------------------

type
  TermKind* = enum
    pkVar
    pkAtom
    pkInt
    pkFloat
    pkString
    pkNil
    pkFunctor
    pkInfix
    pkModule
    pkProgram
    pkList
    pkChars
    pkBool
    pkDict

  SourceList* = seq[Source]

  Source* = ref object
    case kind*: TermKind
    of pkVar, pkAtom: name*: string
    of pkInt: int_val*: int64
    of pkFloat: float_val*: float64
    of pkString: string_val*: string
    of pkNil: nil
    of pkFunctor:
      predicate*: string
      args*: SourceList
    of pkInfix:
      operator*: string
      head*: Source
      body*: SourceList
    of pkModule: top: string
    of pkProgram: terms*: SourceList
    of pkChars: char_val*: cstring
    of pkList: list*: SourceList
    of pkBool: bool_val*: bool
    of pkDict:
      tag*: string
      dict*: TableRef[string, Source]
    comments*: seq[string]
    ns*: string

  SourceError* = object of IOError

let NONE* = Source(kind: pkNil)

# -----------------------------------------------------------------------
# String representation
# -----------------------------------------------------------------------

raise_value()

proc `$`*(term: Source): string {.value_err.} =
  result = case term.kind
    of pkVar: term.name.capitalizeAscii()
    of pkAtom: term.name
    of pkInt: $term.int_val
    of pkFloat: $term.float_val
    of pkString:
      if term.string_val.len > 0 and term.string_val[0] in {'a'..'z'} and
         term.string_val.allCharsInSet({'a'..'z', 'A'..'Z', '0'..'9', '_'}):
        term.string_val
      else:
        term.string_val.escape_quote()
    of pkFunctor:
      if term.args.len == 0: term.predicate
      else:
        let args = collect(newSeqOfCap(term.args.len)):
          for a in term.args: $a
        &"{term.predicate}({args.join(COMMA)})"
    of pkInfix:
      let body =
        if term.body.len == 1: $term.body.first
        else:
          let bp = collect(newSeqOfCap(term.body.len)):
            for b in term.body: $b
          bp.join(COMMA)
      &"{$term.head} {term.operator} ({body})"
    of pkProgram:
      let terms = collect(newSeqOfCap(term.terms.len)):
        for t in term.terms: &"{t}.\n"
      terms.join(BLANK)
    of pkList:
      let pl = collect(newSeqOfCap(term.list.len)):
        for e in term.list: $e
      &"[{pl.join(COMMA)}]"
    of pkChars: $term.char_val
    of pkBool: $term.bool_val
    of pkDict:
      let kv = collect(newSeqOfCap(term.dict.len)):
        for k, v in term.dict.pairs: &"{k}: {v}"
      &"{term.tag}{{{kv.join(COMMA)}}}"
    else: BLANK
  if term.comments.len > 0:
    let comments = collect(newSeqOfCap(term.comments.len)):
      for c in term.comments: &"% {c}\n"
    result = &"{comments.join(BLANK)}{result}"

# -----------------------------------------------------------------------
# Constructors
# -----------------------------------------------------------------------

proc program_source*(terms: varargs[Source]): Source {.ok.} =
  Source(kind: pkProgram, terms: @terms)

proc functor_source*(predicate: string, args: varargs[Source]): Source {.ok.} =
  Source(kind: pkFunctor, predicate: predicate, args: @args)

proc infix_source*(operator: string, head: Source, body: varargs[Source]): Source {.ok.} =
  Source(kind: pkInfix, operator: operator, head: head, body: @body)

proc var_source*(value: string): Source {.ok.} =
  Source(kind: pkVar, name: value)

proc atom_source*(value: string): Source {.ok.} =
  Source(kind: pkAtom, name: value)

proc int_source*(value: BiggestInt): Source {.ok.} =
  Source(kind: pkInt, int_val: value)

proc float_source*(value: float): Source {.ok.} =
  Source(kind: pkFloat, float_val: value)

proc string_source*(value: string): Source {.ok.} =
  Source(kind: pkString, string_val: value)

proc chars_source*(value: cstring): Source {.ok.} =
  Source(kind: pkChars, char_val: value)

proc list_source*(value: varargs[Source]): Source {.ok.} =
  Source(kind: pkList, list: @value)

proc bool_source*(value: bool): Source {.ok.} =
  Source(kind: pkBool, bool_val: value)

proc dict_source*(value: openArray[(string, Source)], tag = "_"): Source {.ok.} =
  Source(kind: pkDict, tag: tag, dict: value.newTable())

proc add*(parent, child: Source) {.ok.} =
  case parent.kind:
  of pkModule: parent.terms.add(child)
  of pkFunctor: parent.args.add(child)
  of pkInfix: parent.body.add(child)
  of pkList: parent.list.add(child)
  else: discard

proc comment*(term: Source, comment: string) {.ok.} =
  term.comments.add(comment)

proc arity*(term: Source): int {.ok.} =
  if term.kind == pkFunctor: term.args.len else: 0

# -----------------------------------------------------------------------
# Macro DSL
# -----------------------------------------------------------------------

proc walk(index: int, source, parent, target: NimNode) {.ok.} =
  case source.kind
  of nnkCall, nnkInfix:
    let call =
      case source.kind
      of nnkCall: newCall("functor_source")
      of nnkInfix: newCall("infix_source")
      else: newCall("functor_source")
    target.add(call)
    for idx, child in source.pairs: walk(idx, child, source, call)
  of nnkCurlyExpr, nnkTableConstr:
    let table = newNimNode(nnkTableConstr)
    let dict = newCall("dict_source").add(table)
    target.add(dict)
    for idx, child in source.pairs:
      if idx == 0 and child.kind == nnkIdent: dict.add(child.strVal.newLit)
      else: walk(idx, child, source, table)
  of nnkBracket:
    let list = newCall("list_source")
    target.add(list)
    for idx, child in source.pairs: walk(idx, child, source, list)
  of nnkIdent, nnkSym:
    let
      identity = source.strVal
      nl = identity.newLit
      term =
        if identity[0].isUpperAscii: newCall("var_source", nl)
        elif parent.kind in XPR_KIND and index == 0: nl
        elif identity in BOOL_NAME: newCall("bool_source", source)
        else: newCall("atom_source", nl)
    target.add(term)
  of nnkExprColonExpr:
    let pair = newNimNode(nnkExprColonExpr)
    target.add(pair)
    for idx, child in source.pairs:
      if idx == 0:
        case child.kind
        of nnkCharLit .. nnkInt64Lit, nnkIdent: pair.add(child.strVal.newLit)
        else: discard
      else: walk(idx, child, source, pair)
  of nnkCharLit..nnkInt64Lit: target.add(newCall("int_source", source))
  of nnkFloatLit..nnkFloat64Lit: target.add(newCall("float_source", source))
  of nnkStrLit..nnkTripleStrLit: target.add(newCall("string_source", source))
  of nnkNilLit: discard
  of nnkNone: discard
  else:
    for idx, child in source.pairs: walk(idx, child, source, target)

{.pop.}

macro prolog*(s: untyped): untyped =
  result = newStmtList()
  walk(0, s, nil, result)
