:- begin_tests(constructive).

:- use_module(src/itc2007/parser).
:- use_module(src/solver/constructive).
:- use_module(src/output/validator).

test(constructive_produces_feasible_solution_for_mini) :-
    once(parser:read_instance('tests/fixtures/mini.ctt', I)),
    once(constructive:construct(I, Sol)),
    validator:check_hard_constraints(I, Sol).

:- end_tests(constructive).
