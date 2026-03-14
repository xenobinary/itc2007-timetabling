:- initialization(run_tests, main).

run_tests :-
    consult(tests/test_parser),
    consult(tests/test_constructive),
    run_tests([parser, constructive]),
    halt(0).
