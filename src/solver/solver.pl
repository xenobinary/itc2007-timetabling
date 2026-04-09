:- module(solver, [solve/4]). % Declare the 'solver' module, exporting solve/4 as the solver dispatcher.

:- use_module(constructive).                   % Import the constructive heuristic solver module.
:- use_module(clpfd_solver, []).               % Import the CLP(FD) solver module (no re-exports needed).
:- use_module('../rules/hard_constraints').    % Import hard constraint rules for post-solve validation.
:- use_module('../rules/soft_constraints').    % Import soft constraint rules for penalty computation.

% solve(+Instance, +Opts, -Solution, -Stats)
% Dispatcher: choose the solver specified in Opts, run it on Instance,
% validate the result, compute the penalty, and return Solution and Stats.
solve(Instance, Opts, Solution, Stats) :-
    solver_name(Opts, SolverName),              % Extract the solver name atom from the options dict.
    (   construct_with(SolverName, Instance, Solution0) % Attempt to construct a solution using the chosen solver.
    ->  Solution = Solution0,                   % If construction succeeded, bind Solution.
        (hard_constraints:feasible(Instance, Solution) -> Feasible=true ; Feasible=false), % Validate solution.
        soft_constraints:penalty(Instance, Solution, Penalty) % Compute total soft-constraint penalty.
    ;   Solution = [],                          % If construction failed, return an empty solution.
        Feasible = false,                       % Mark the result infeasible.
        Penalty = 0                             % Report zero penalty for an empty/infeasible solution.
    ),
    Stats = stats{feasible:Feasible, penalty:Penalty}. % Pack feasibility flag and penalty into a stats dict.

% solver_name(+Opts, -SolverName)
% Extract the solver name from the options dict, defaulting to 'constructive'.
solver_name(Opts, SolverName) :-
    (   get_dict(solver, Opts, SolverName0)    % Look up the 'solver' key in the options dict.
    ->  SolverName = SolverName0               % If present, use the specified solver name.
    ;   SolverName = constructive              % If absent, default to the constructive heuristic solver.
    ).

% construct_with(+SolverName, +Instance, -Solution)
% Dispatch to the correct solver predicate based on SolverName.
construct_with(clpfd, Instance, Solution) :-       % Clause for the 'clpfd' solver.
    !,                                             % Cut: matched this clause, do not try others.
    clpfd_solver:construct(Instance, Solution).    % Delegate to CLP(FD) solver's construct/2.
construct_with(constructive, Instance, Solution) :- % Clause for the 'constructive' solver.
    !,                                             % Cut: matched this clause, do not try others.
    constructive:construct(Instance, Solution).    % Delegate to the constructive solver's construct/2.
construct_with(_, Instance, Solution) :-           % Fallback clause for any unknown solver name.
    constructive:construct(Instance, Solution).    % Default to the constructive solver.
