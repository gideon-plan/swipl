{.experimental: "strictFuncs".}
## FFI smoke tests.

import std/unittest

import swipl/ffi

suite "ffi smoke":
  test "enum values":
    check ord(plVariable) == 1
    check ord(plAtom) == 2
    check ord(plInteger) == 3
    check ord(plFloat) == 5
    check ord(plString) == 6
    check ord(plTerm) == 7
