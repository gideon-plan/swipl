## Goal and solution integration tests.

import std/unittest

import swipl/api
import swipl/dsl
import swipl/goal
import swipl/solution

suite "swipl integration":
  var engine: SWIPL

  setup:
    if engine == nil:
      engine = initialize()

  test "initialize engine":
    check engine != nil
    check engine.init

  test "call atom":
    check engine.call("true")

  test "call fail":
    check not engine.call("fail")

  test "assertz and call":
    engine.scope:
      check engine.assertz("test_fact(42)")
      check engine.call("test_fact(42)")

  test "run string evaluation":
    engine.scope:
      let sol = engine.run("X = hello")
      check not sol.isNil

  test "call compound":
    engine.scope:
      check engine.call("member(a, [a,b,c])")
