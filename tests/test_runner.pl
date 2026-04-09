:- initialization(run_tests, main). % When loaded as a script, call run_tests/0 as the entry point.

:- ensure_loaded('test_parser.pl').              % Load the parser test suite.
:- ensure_loaded('test_constructive.pl').        % Load the constructive solver test suite.
:- ensure_loaded('test_hard_constraints_clpfd.pl'). % Load the CLP(FD) hard-constraints test suite.
:- ensure_loaded('test_clpfd_solver.pl').        % Load the CLP(FD) solver test suite.

% run_tests/0
% Execute all registered test suites and exit with code 0 on success.
run_tests :-
    run_tests([parser, constructive, hard_constraints_clpfd]), % Run first batch of suites.
    run_tests([parser, constructive, clpfd_solver]),           % Run second batch (re-runs parser/constructive for safety).
    halt(0).                                                   % Exit cleanly after all tests pass.
