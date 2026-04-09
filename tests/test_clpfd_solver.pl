:- begin_tests(clpfd_solver). % Open the 'clpfd_solver' plunit test suite.

:- use_module('../src/itc2007/parser').        % Load the parser to read the test fixture.
:- use_module('../src/solver/clpfd_solver').   % Load the CLP(FD) solver under test.
:- use_module('../src/rules/hard_constraints'). % Load feasibility checker to validate the solution.

% test: clpfd_solver_produces_feasible_solution_for_mini
% Verify that the CLP(FD) solver produces a hard-constraint-feasible solution
% for the small 'mini' fixture instance.
test(clpfd_solver_produces_feasible_solution_for_mini) :-
    once(parser:read_instance('tests/fixtures/mini.ctt', Instance)), % Parse the mini fixture; keep first solution.
    once(clpfd_solver:construct(Instance, Solution)),                 % Run the CLP(FD) solver; keep first solution.
    hard_constraints:feasible(Instance, Solution).                    % Assert the solution satisfies all hard constraints.

:- end_tests(clpfd_solver). % Close the 'clpfd_solver' test suite.
