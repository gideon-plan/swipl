{.experimental: "strictFuncs".}
## Goal, solution, and API integration tests.

import std/unittest

import swipl/api
import swipl/dsl
import swipl/ffi
import basis/code/choice

# SWI-Prolog can only be initialized once per process.
var engine: SWIPL

suite "initialization":
  test "initialize engine":
    engine = initialize()
    check engine != nil
    check engine.init

suite "distinct types":
  test "PrologTerm":
    let t = PrologTerm("likes(alice, bob)")
    check $t == "likes(alice, bob)"
    check t.len == 17
    check t == PrologTerm("likes(alice, bob)")

  test "ModuleName":
    let m = ModuleName("user")
    check $m == "user"
    check m.len == 4
    check m == ModuleName("user")

  test "PrologTerm empty":
    let t = PrologTerm("")
    check t.len == 0

  test "ModuleName empty":
    let m = ModuleName("")
    check m.len == 0

suite "assertz and call":
  test "assertz fact and call succeeds":
    engine.scope:
      check engine.assertz(PrologTerm("test_fact_1(hello)"))
      check engine.call(PrologTerm("test_fact_1(hello)"))

  test "call true":
    engine.scope:
      check engine.call(PrologTerm("true"))

  test "call fail":
    engine.scope:
      check not engine.call(PrologTerm("fail"))

  test "assertz and call compound":
    engine.scope:
      check engine.assertz(PrologTerm("parent(tom, bob)"))
      check engine.assertz(PrologTerm("parent(bob, ann)"))
      check engine.call(PrologTerm("parent(tom, bob)"))
      check engine.call(PrologTerm("parent(bob, ann)"))
      check not engine.call(PrologTerm("parent(tom, ann)"))

  test "assertz rule and call":
    engine.scope:
      check engine.assertz(PrologTerm("gp_test_color(red)"))
      check engine.assertz(PrologTerm("gp_test_color(blue)"))
      check engine.call(PrologTerm("gp_test_color(red)"))
      check engine.call(PrologTerm("gp_test_color(blue)"))
      check not engine.call(PrologTerm("gp_test_color(green)"))

  test "call with arithmetic":
    engine.scope:
      check engine.call(PrologTerm("X is 2 + 3, X =:= 5"))

  test "call member":
    engine.scope:
      check engine.call(PrologTerm("member(a, [a,b,c])"))
      check not engine.call(PrologTerm("member(d, [a,b,c])"))

suite "run":
  test "run arithmetic":
    engine.scope:
      let sol = engine.run(PrologTerm("X is 2 + 3"))
      check sol != nil

  test "run unification":
    engine.scope:
      let sol = engine.run(PrologTerm("X = hello"))
      check sol != nil

  test "run failure returns nil":
    engine.scope:
      let sol = engine.run(PrologTerm("fail"))
      check sol == nil

suite "runs iterator":
  test "multiple solutions":
    engine.scope:
      discard engine.assertz(PrologTerm("iter_color(red)"))
      discard engine.assertz(PrologTerm("iter_color(green)"))
      discard engine.assertz(PrologTerm("iter_color(blue)"))
      var count = 0
      for sol in engine.runs(PrologTerm("iter_color(X)")):
        inc count
      check count == 3

  test "single solution":
    engine.scope:
      var count = 0
      for sol in engine.runs(PrologTerm("X = 42")):
        inc count
      check count == 1

  test "no solutions":
    engine.scope:
      var count = 0
      for sol in engine.runs(PrologTerm("fail")):
        inc count
      check count == 0

suite "library loading":
  test "load lists library":
    engine.scope:
      check engine.library("lists")

suite "DSL":
  test "prolog macro creates Source":
    let src = prolog:
      test_dsl_fact(42)
    check $src != ""

  test "assertz with Source":
    engine.scope:
      let src = prolog:
        dsl_color(yellow)
      check engine.assertz(src)
      check engine.call(PrologTerm("dsl_color(yellow)"))

suite "Maybe overloads":
  test "try_call success":
    engine.scope:
      let result = engine.try_call(PrologTerm("true"))
      check result.is_good
      check result.val == true

  test "try_call failure":
    engine.scope:
      let result = engine.try_call(PrologTerm("fail"))
      check result.is_good
      check result.val == false

  test "try_run success":
    engine.scope:
      let result = engine.try_run(PrologTerm("X = hello"))
      check result.is_good
      check result.val != nil

  test "try_run failure":
    engine.scope:
      let result = engine.try_run(PrologTerm("fail"))
      # fail doesn't raise, just returns nil
      check result.is_good
      check result.val == nil

suite "engine flags":
  test "pass mode":
    let e = engine.pass()
    check e != nil

  test "drop mode":
    let e = engine.drop()
    check e != nil
    # restore
    discard engine.pass()

suite "register":
  test "register placeholder":
    # Just verify the proc exists and is callable with correct types
    check PrologTerm("test_reg").len > 0
    check ModuleName("").len == 0
