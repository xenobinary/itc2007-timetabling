:- initialization(run_tests, main).

:- ensure_loaded('test_parser.pl').
:- ensure_loaded('test_constructive.pl').
:- ensure_loaded('test_hard_constraints_clpfd.pl').

run_tests :-
    run_tests([parser, constructive, hard_constraints_clpfd]),
:- ensure_loaded('test_clpfd_solver.pl').

run_tests :-
    run_tests([parser, constructive, clpfd_solver]),
    halt(0).
