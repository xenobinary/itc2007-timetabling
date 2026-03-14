:- module(validate, [main/1]).

:- use_module(src/itc2007/parser).
:- use_module(src/output/solution_reader).
:- use_module(src/rules/hard_constraints).
:- use_module(src/rules/soft_constraints).

main(Argv) :-
    (   parse_args(Argv, InstancePath, SolPath)
    ->  true
    ;   print_help,
        halt(1)
    ),
    parser:read_instance(InstancePath, Instance),
    solution_reader:read_solution(SolPath, Solution),
    (   hard_constraints:feasible(Instance, Solution)
    ->  soft_constraints:penalty(Instance, Solution, Penalty),
        format('OK: feasible solution. penalty=~d~n', [Penalty]),
        halt(0)
    ;   (   hard_constraints:violates(Instance, Solution, Reason)
        ->  format('FAIL: infeasible solution. reason=~w~n', [Reason])
        ;   format('FAIL: infeasible solution. reason=unknown~n', [])
        ),
        halt(2)
    ).

parse_args(Argv, _InstancePath, _SolPath) :-
    ( member('--help', Argv) ; member('-h', Argv) ),
    !,
    fail.
parse_args(Argv, InstancePath, SolPath) :-
    option_value('--instance', Argv, InstancePath),
    option_value('--solution', Argv, SolPath),
    InstancePath \= '',
    SolPath \= ''.

option_value(Flag, [Flag,Val|_], Val) :- !.
option_value(Flag, [_|Rest], Val) :- option_value(Flag, Rest, Val).
option_value(_Flag, [], '').

print_help :-
    format('Validate an ITC2007 solution file against an instance.\n', []),
    format('Usage:\n', []),
    format('  swipl -q -g "[src/validate], main([\'--instance\',\'<file.ctt>\',\'--solution\',\'<file.sol>\'])" -t halt\n', []).
