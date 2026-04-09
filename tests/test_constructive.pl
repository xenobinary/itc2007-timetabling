:- begin_tests(constructive). % Open the 'constructive' plunit test suite.

:- use_module('../src/itc2007/parser').        % Load the parser to read the test fixture.
:- use_module('../src/solver/constructive').   % Load the constructive solver under test.
:- use_module('../src/rules/hard_constraints'). % Load feasibility checker to validate the solution.

% test: constructive_produces_feasible_solution_for_mini
% Verify that the greedy constructive solver produces a hard-constraint-feasible solution
% for the small 'mini' fixture instance.
test(constructive_produces_feasible_solution_for_mini) :-
    once(parser:read_instance('tests/fixtures/mini.ctt', I)), % Parse the mini fixture; keep first solution.
    once(constructive:construct(I, Sol)),                      % Run the constructive solver; keep first solution.
    hard_constraints:feasible(I, Sol).                         % Assert the solution satisfies all hard constraints.

:- end_tests(constructive). % Close the 'constructive' test suite.
