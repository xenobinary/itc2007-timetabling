:- initialization(run_tests, main).

:- ensure_loaded('test_parser.pl').
:- ensure_loaded('test_constructive.pl').
:- ensure_loaded('test_hard_constraints_clpfd.pl').

run_tests :-
    run_tests([parser, constructive, hard_constraints_clpfd]),
    halt(0).
