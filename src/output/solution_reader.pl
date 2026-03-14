:- module(solution_reader, [read_solution/2]).

:- use_module(library(readutil)).
:- use_module(library(lists)).
:- use_module(library(assoc)).

% Reads an ITC2007 Track2 solution file with lines:
%   CourseId RoomId Day Period
% and reconstructs internal assignments:
%   assignment(CourseId, LectureIndex, Day, Period, RoomId)
%
% LectureIndex is assigned in read order per course (0..).

read_solution(Path, Assignments) :-
    setup_call_cleanup(
        open(Path, read, S),
        read_stream_to_codes(S, Codes),
        close(S)
    ),
    atom_codes(Atom, Codes),
    split_string(Atom, "\n", "\r", Lines0),
    exclude(blank_line, Lines0, Lines),
    empty_assoc(A0),
    foldl(parse_sol_line, Lines, state(A0, []), state(_A, RevAssignments)),
    reverse(RevAssignments, Assignments).

blank_line(S) :-
    string_codes(S, Codes),
    Codes \= [],
    forall(member(C, Codes), (C=0' ; C=0'\t)).
blank_line("").

parse_sol_line(Line, state(A0, Acc0), state(A, [assignment(Course, Index, Day, Period, Room)|Acc0])) :-
    split_string(Line, " \t", " \t", [Course, Room, DayS, PeriodS]),
    number_string(Day, DayS),
    number_string(Period, PeriodS),
    next_index(Course, A0, Index, A),
    !.
parse_sol_line(Line, State, State) :-
    % Ignore malformed lines but warn.
    format(user_error, 'Skipping malformed sol line: ~s~n', [Line]).

next_index(Course, A0, Index, A) :-
    (   get_assoc(Course, A0, Cur)
    ->  Index is Cur,
        Next is Cur + 1,
        put_assoc(Course, A0, Next, A)
    ;   Index = 0,
        put_assoc(Course, A0, 1, A)
    ).
