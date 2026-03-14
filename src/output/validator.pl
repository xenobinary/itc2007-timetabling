:- module(validator, [check_hard_constraints/2]).

:- use_module(src/rules/hard_constraints).

check_hard_constraints(Instance, Solution) :-
    hard_constraints:feasible(Instance, Solution).
