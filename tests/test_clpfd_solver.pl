:- begin_tests(clpfd_solver).

:- use_module('../src/itc2007/parser').
:- use_module('../src/solver/clpfd_solver').
:- use_module('../src/rules/hard_constraints').

test(clpfd_solver_produces_feasible_solution_for_mini) :-
    once(parser:read_instance('tests/fixtures/mini.ctt', Instance)),
    once(clpfd_solver:construct(Instance, Solution)),
    hard_constraints:feasible(Instance, Solution).

:- end_tests(clpfd_solver).
