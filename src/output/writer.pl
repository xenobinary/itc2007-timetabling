:- module(writer, [write_solution/2, write_csv/2]). % Declare module; export write_solution/2 and write_csv/2.

:- use_module(library(lists)). % Import lists library (used implicitly by member/2 in forall/2).
:- use_module(library(csv)).   % Import SWI-Prolog CSV library for csv_write_stream/3.

% write_solution(+Path, +Solution)
% Write the solution to a text file in ITC2007 format: "CourseId RoomId Day Period" per line.
write_solution(Path, Solution) :-
    setup_call_cleanup(               % Open file; write; close — even on exception.
        open(Path, write, S),         % Open Path for writing; bind stream to S.
        (   forall(member(assignment(C,_I,D,P,R), Solution), % Iterate over every assignment term.
                format(S, '~w ~w ~d ~d~n', [C, R, D, P]))   % Write: CourseId RoomId Day Period\n.
        ),
        close(S)                      % Close the stream unconditionally when done.
    ).

% write_csv(+Path, +Stats)
% Write a two-row CSV file (header + one data row) with feasibility and penalty stats.
write_csv(Path, Stats) :-
    Rows = [row(feasible, penalty), row(Stats.feasible, Stats.penalty)], % Build header + data rows.
    setup_call_cleanup(               % Open file; write; close — even on exception.
        open(Path, write, S),         % Open Path for writing; bind stream to S.
        csv_write_stream(S, Rows, []),% Write all rows as CSV (no extra options).
        close(S)                      % Close the stream unconditionally when done.
    ).
