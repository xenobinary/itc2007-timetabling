:- module(solver, [solve/4]).

:- use_module(constructive).
:- use_module(clpfd_solver, []).
:- use_module('../rules/hard_constraints').
:- use_module('../rules/soft_constraints').

solve(Instance, Opts, Solution, Stats) :-
    solver_name(Opts, SolverName),
    (   construct_with(SolverName, Instance, Solution0)
    ->  Solution = Solution0,
        (hard_constraints:feasible(Instance, Solution) -> Feasible=true ; Feasible=false),
        soft_constraints:penalty(Instance, Solution, Penalty)
    ;   Solution = [],
        Feasible = false,
        Penalty = 0
    ),
    Stats = stats{feasible:Feasible, penalty:Penalty}.

solver_name(Opts, SolverName) :-
    (   get_dict(solver, Opts, SolverName0)
    ->  SolverName = SolverName0
    ;   SolverName = constructive
    ).

construct_with(clpfd, Instance, Solution) :-
    !,
    clpfd_solver:construct(Instance, Solution).
construct_with(constructive, Instance, Solution) :-
    !,
    constructive:construct(Instance, Solution).
construct_with(_, Instance, Solution) :-
    constructive:construct(Instance, Solution).
