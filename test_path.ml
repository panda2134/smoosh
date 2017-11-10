open Test_prelude
open Fsh
open Path
open Printf

(* test_name expected got *)
type 'a result = Ok | Err of 'a err
  and 'a err = { msg : string;  expected : 'a; got : 'a }

let rec intercalate sep ss = 
  match ss with
  | [] -> ""
  | [s] -> s
  | s::ss' -> s ^ sep ^ intercalate sep ss'

let show_set set =
  "{" ^ intercalate "," (Pset.elements set) ^ "}"

let checker test_fn equal (test_name, input, expected_out) =
  let out = test_fn input in
  if equal out expected_out
  then Ok
  else Err {msg = test_name; expected = expected_out; got = out}

let check_match_path (name, state, path, expected) =
  checker (match_path state Locale.lc_ambient) Pset.equal (name, path, (Pset.from_list compare expected))

let match_path_tests : (string * ty_os_state * string * (string list)) list =
  [
    ("Root in empty", os_empty, "/", ["/"]);
    (* Sample fs state
     * /
     *   a/
     *     use/
     *       x
     *     user/
     *       x
     *       y
     *     useful
     *   b/
     *     user/
     *       z
     *   c/
     *      foo
     *
     *
     *  in /a
     *      use* => use, user, useful
     *      use*/ => use/ user/
     *      use*/* => use/x, user/x, user/y
     *
     *  see egs/path for more examples
     *)
  ]

let test_part name checker stringOfExpected tests count failed =
  List.iter
    (fun t ->
      match checker t with
      | Ok -> incr count
      | Err e ->
         printf "%s test: %s failed: expected '%s' got '%s'\n"
                name e.msg (stringOfExpected e.expected) (stringOfExpected e.got);
         incr count; incr failed)
    tests

let run_tests () =
  let failed = ref 0 in
  let test_count = ref 0 in
  let prnt = fun (s, n) -> ("<| " ^ (print_shell_env s) ^ "; " ^ (Fsh.fields_to_string_crappy n) ^ " |>") in
  print_endline "\n=== Running path/fs tests...";
  (* core path matching tests *)
  test_part "Match path" check_match_path show_set match_path_tests test_count failed;

  printf "=== ...ran %d path/fs tests with %d failures.\n\n" !test_count !failed
