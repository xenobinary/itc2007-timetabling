:- module(writer, [write_solution/2, write_csv/2]).

:- use_module(library(lists)).
:- use_module(library(csv)).

write_solution(Path, Solution) :-
    setup_call_cleanup(
        open(Path, write, S),
        (   forall(member(assignment(C,_I,D,P,R), Solution),
                format(S, '~w ~w ~d ~d~n', [C, R, D, P]))
        ),
        close(S)
    ).

write_csv(Path, Stats) :-
    Rows = [row(feasible, penalty), row(Stats.feasible, Stats.penalty)],
    setup_call_cleanup(
        open(Path, write, S),
        csv_write_stream(S, Rows, []),
        close(S)
    ).
