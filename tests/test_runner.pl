:- initialization(run_tests, main).

:- ensure_loaded('test_parser.pl').
:- ensure_loaded('test_constructive.pl').

run_tests :-
    run_tests([parser, constructive]),
    halt(0).
