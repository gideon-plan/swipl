# swipl

SWI-Prolog binding for Nim. Supports term creation, assertion, queries, foreign frame management, Prolog DSL macro, and FFI registration.

## Install

```
nimble install
```

## Usage

```nim
import swipl

let engine = initialize()
engine.scope:
  discard engine.assertz(PrologTerm("likes(alice, bob)"))
  echo engine.call(PrologTerm("likes(alice, bob)"))
```

## License

Proprietary
