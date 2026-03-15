#[
=================
SWI-Prolog → Main
=================

https://nim-lang.org/docs/nimscript.html
https://nim-lang.org/docs/nims.html
]#

#=======================================================================================================================
#== INIT ===============================================================================================================
#=======================================================================================================================

package_name = "swipl"

mode = ScriptMode.Silent

# std...
import std/os
import std/strutils

#=======================================================================================================================
#== SWITCH =============================================================================================================
#=======================================================================================================================

--mm:orc
--list_cmd
--outdir:".out"
--verbosity:1
--line_dir:on

switch("nimcache", $CurDir/".nimcache")

--define:nim_preview_dot_like_ops
--define:nim_preview_float_roundtrip
--define:nim_strict_delete
--define:nim_no_get_random
--experimental:unicode_operators
--experimental:overloadable_enums

--style_check:usages

switch("passc", "-I/usr/lib/swi-prolog/include")
switch("passc", "-Wno-incompatible-pointer-types")
switch("passl", "-L/usr/lib/swi-prolog/lib/x86_64-linux -lswipl -Wl,-rpath,/usr/lib/swi-prolog/lib/x86_64-linux")

when defined(code_coverage):
  switch("passc", "-fprofile-arcs -fprofile-generate -coverage")
  switch("passl", "-lgcov")

#=======================================================================================================================
#== TEST ===============================================================================================================
#=======================================================================================================================

task test, "Run all tests":
  exec "nim r --path:src tests/tswipl.nim"

when file_exists("nimble.paths"):
  include "nimble.paths"
# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config
