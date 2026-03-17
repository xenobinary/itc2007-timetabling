:- module(solver, [solve/4]).

:- use_module(constructive).
:- use_module('../rules/hard_constraints').
:- use_module('../rules/soft_constraints').

solve(Instance, _Opts, Solution, Stats) :-
    (   constructive:construct(Instance, Solution0)
    ->  Solution = Solution0,
        (hard_constraints:feasible(Instance, Solution) -> Feasible=true ; Feasible=false),
        soft_constraints:penalty(Instance, Solution, Penalty)
    ;   Solution = [],
        Feasible = false,
        Penalty = 0
    ),
    Stats = stats{feasible:Feasible, penalty:Penalty}.
