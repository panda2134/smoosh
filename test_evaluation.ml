open Test_prelude
open Fsh
open Path
open Printf

(***********************************************************************)
(* EXIT CODE TESTS *****************************************************)
(***********************************************************************)

let get_exit_code (os : symbolic os_state) =
  match lookup_concrete_param os "?" with
  | Some digits ->
     begin 
       try int_of_string digits
       with Failure "int_of_string" -> 257 (* unrepresentable in shell *)
     end
  | None -> 258
   
let run_cmd_for_exit_code (cmd : string) (os0 : symbolic os_state) : int =
  let cs = Shim.parse_string cmd in
  let os1 = Semantics.full_evaluation_multi os0 cs in
  get_exit_code os1

let check_exit_code (cmd, state, expected) =
  checker (run_cmd_for_exit_code cmd) (=) (cmd, state, expected)
 
let exit_code_tests : (string * symbolic os_state * int) list =
  (* basic logic *)
  [ ("true", os_empty, 0)
  ; ("false", os_empty, 1)
  ; ("true && true", os_empty, 0)
  ; ("true && false", os_empty, 1)
  ; ("false && true", os_empty, 1)
  ; ("false || true", os_empty, 0)
  ; ("false ; true", os_empty, 0)
  ; ("true ; false", os_empty, 1)
  ; ("! true", os_empty, 1)
  ; ("! false", os_empty, 0)
  ; ("! { true ; false ; }", os_empty, 0)
  ; ("! { false ; true ; }", os_empty, 1)

  (* expansion *)
  ; ("x=5 ; echo ${x?erp}", os_empty, 0)
  ; ("echo ${x?erp}", os_empty, 1)
  ; ("for y in ${x?oh no}; do exit 5; done", os_empty, 1)
  ; ("x=5 ; for y in ${x?oh no}; do exit $y; done", os_empty, 5)
  ; ("case ${x?alas} in *) true;; esac", os_empty, 1)
  ; ("x=7 ; case ${x?alas} in *) exit $x;; esac", os_empty, 7)
  ; ("x=$(echo 5) ; exit $x", os_empty, 5)
  ; ("x=$(echo hello) ; case $x in *ell*) true;; *) false;; esac", os_empty, 0)

  (* exit *)
  ; ("exit", os_empty, 0)
  ; ("exit 2", os_empty, 2)
  ; ("false; exit", os_empty, 1)
  ; ("false; exit 2", os_empty, 2)
  
  (* break *)
  ; ("while true; do break; done", os_empty, 0)

  (* for loop with no args should exit 0 *)
  ; ("for x in; do exit 1; done", os_empty, 0)
  ; ("for x in \"\"; do exit 1; done", os_empty, 1)

  (* case cascades *)
  ; ("case abc in ab) true;; abc) false;; esac", os_empty, 1)
  ; ("case abc in ab|ab*) true;; abc) false;; esac", os_empty, 0)
  ; ("case abc in *) true;; abc) false;; esac", os_empty, 0)
  ; ("x=hello ; case $x in *el*) true;; *) false;; esac", os_empty, 0)
  ; ("case \"no one is home\" in esac", os_empty, 0)

  (* pipes *)
  ; ("false | true", os_empty, 0)
  ; ("true | false", os_empty, 1)
  ; ("true | exit 5", os_empty, 5)

  (* unset *)
  ; ("x=5 ; exit $x", os_empty, 5)
  ; ("x=5 ; unset x; exit $x", os_empty, 0)
  ; ("x=5 ; unset x; exit ${x-42}", os_empty, 42)
  ; ("f() { exit 3 ; } ; f", os_empty, 3)
  ; ("f() { exit 3 ; } ; unset f ; f", os_empty, 3)
  ; ("f() { exit 3 ; } ; unset -f f ; f", os_empty, 127)

  (* readonly *)
  ; ("x=5 ; readonly x", os_empty, 0)
  ; ("x=5 ; readonly x ; ! readonly x=10", os_empty, 0)
  ; ("x=- ; ! readonly $x=derp", os_empty, 0)

  (* export *)
  ; ("x=- ; ! export $x=derp", os_empty, 0)

  (* eval *)
  ; ("eval exit 0", os_empty, 0)
  ; ("eval exit 1", os_empty, 1)
  ; ("! ( eval exit 1 )", os_empty, 0)
  ; ("! eval exit 1", os_empty, 1)
  ; ("! eval exit 47", os_empty, 47)

  (* function calls *)
  ; ("g() { exit 5 ; } ; h() { exit 6 ; } ; i() { $1 ; exit 7 ; } ; i g", os_empty, 5)
  ; ("g() { exit 5 ; } ; h() { exit 6 ; } ; i() { $1 ; exit 7 ; } ; i h", os_empty, 6)
  ; ("g() { exit 5 ; } ; h() { exit 6 ; } ; i() { $1 ; exit 7 ; } ; i :", os_empty, 7)

  (* $# *)
  ; ("f() { exit $# ; } ; f", os_empty, 0)
  ; ("f() { exit $# ; } ; f a", os_empty, 1)
  ; ("f() { exit $# ; } ; f a b", os_empty, 2)
  ; ("f() { exit $# ; } ; f a b c", os_empty, 3)
  ; ("f() { $@ ; } ; f exit 12", os_empty, 12)
  ; ("f() { $* ; } ; f exit 12", os_empty, 12)

  (* set *)
  ; ("set -- a b c; exit $#", os_empty, 3)
  ; ("set -- ; exit $#", os_empty, 0)
  ; ("set -n ; exit 5", os_empty, 0)
  ; ("set -u ; echo $x", os_empty, 1)
  ]

(***********************************************************************)
(* STDOUT TESTS ********************************************************)
(***********************************************************************)


let run_cmd_for_stdout (cmd : string) (os0 : symbolic os_state) : string =
  let cs = Shim.parse_string cmd in
  let os1 = Semantics.full_evaluation_multi os0 cs in
  get_stdout os1

let check_stdout (cmd, state, expected) =
  checker (run_cmd_for_stdout cmd) (=) (cmd, state, expected)

let stdout_tests : (string * symbolic os_state * string) list =
    (* basic logic *)
  [ ("true", os_empty, "")
  ; ("false", os_empty, "")
  ; ("echo hi ; echo there", os_empty, "hi\nthere\n")
  ; ("echo -n hi ; echo there", os_empty, "hithere\n")
  ; ("echo -n \"hi \" ; echo there", os_empty, "hi there\n")
  ; ("x=${y:=1} ; echo $((x+=`echo 2`))", os_empty, "3\n")

    (* redirects and pipes *)
  ; ("( echo ${x?oops} ) 2>&1", os_empty, "x: oops\n")
  ; ("echo hi | echo no", os_empty, "no\n")
  ; ("echo ${y?oh no}", os_empty, "")
  ; ("exec 2>&1; echo ${y?oh no}", os_empty, "y: oh no\n")
  ; ("echo ${y?oh no}", os_empty, "")
  ; ("exec 1>&2; echo ${y?oh no}", os_empty, "")

    (* $* vs $@ 

       e.g.s from https://stackoverflow.com/questions/12314451/accessing-bash-command-line-args-vs/12316565
     *)
  ; ("set -- 'arg  1' 'arg  2' 'arg  3' ; for x in $*; do echo \"$x\"; done",
     os_empty,
     "arg\n1\narg\n2\narg\n3\n")
  ; ("set -- 'arg  1' 'arg  2' 'arg  3' ; for x in $@; do echo \"$x\"; done",
     os_empty,
     "arg\n1\narg\n2\narg\n3\n")
  ; ("set -- 'arg  1' 'arg  2' 'arg  3' ; for x in \"$*\"; do echo \"$x\"; done",
     os_empty,
     "arg  1 arg  2 arg  3\n")
  ; ("set -- 'arg  1' 'arg  2' 'arg  3' ; for x in \"$@\"; do echo \"$x\"; done",
     os_empty,
     "arg  1\narg  2\narg  3\n")
  ; ("set -- 'arg  1' 'arg  2' 'arg  3' ; for x in \"$@\"; do echo $x; done",
     os_empty,
     "arg 1\narg 2\narg 3\n")
  ]


(***********************************************************************)
(* DRIVER **************************************************************)
(***********************************************************************)

let run_tests () =
  let failed = ref 0 in
  let test_count = ref 0 in
  print_endline "\n=== Initializing Dash parser...";
  Dash.initialize ();
  print_endline "=== Running evaluation tests...";
  test_part "Exit code" check_exit_code string_of_int exit_code_tests test_count failed;
  test_part "Output on STDOUT" check_stdout (fun s -> s) stdout_tests test_count failed;
  printf "=== ...ran %d evaluation tests with %d failures.\n\n" !test_count !failed

