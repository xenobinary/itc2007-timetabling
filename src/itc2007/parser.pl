:- module(parser, [read_instance/2]).

:- use_module(library(readutil)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(model).

read_instance(Path, Instance) :-
    setup_call_cleanup(
        open(Path, read, S),
        read_stream_to_codes(S, Codes),
        close(S)
    ),
    atom_codes(Atom, Codes),
    split_string(Atom, "\n", "\r", Lines0),
    filter_blank_lines(Lines0, Lines),
    parse_header(Lines, AfterHeader, I0),
    parse_sections_official(AfterHeader, I0, Instance).

filter_blank_lines([], []).
filter_blank_lines([L|Ls], Result) :-
    (   blank_line(L)
    ->  filter_blank_lines(Ls, Result)
    ;   Result = [L|Rest],
        filter_blank_lines(Ls, Rest)
    ).

blank_line(S) :-
    string_codes(S, Codes),
    forall(member(C, Codes), (C=32 ; C=9)).

parse_header(Lines, Rest, I) :-
    model:empty_instance(I0),
    take_kv(Lines, HeaderKVs, Rest0),
    header_to_instance(HeaderKVs, I0, I1),
    reverse_instance_lists(I1, I),
    Rest = Rest0.

reverse_instance_lists(I0, I) :-
    reverse(I0.courses, Courses),
    reverse(I0.rooms, Rooms),
    reverse(I0.curricula, Curricula),
    reverse(I0.unavailability, Unav),
    I = I0.put(_{courses:Courses, rooms:Rooms, curricula:Curricula, unavailability:Unav}).

% Take initial lines formatted as "Key: Value" until a non-matching line.
take_kv([L|Ls], [K=V|KVs], Rest) :-
    split_string(L, ":", " ", [K0|Vs]),
    Vs \= [],
    normalize_space(string(K), K0),
    atomic_list_concat(Vs, ':', VAtom),
    atom_string(VAtom, VStr0),
    normalize_space(string(V), VStr0),
    V \= "",
    !,
    take_kv(Ls, KVs, Rest).
take_kv(Rest, [], Rest).

header_to_instance([], I, I).
header_to_instance([K=V|Rest], I0, I) :-
    (   K == "Name" -> I1 = I0.put(name, V)
    ;   K == "Courses" -> number_string(N, V), I1 = I0.put(courses_count, N)
    ;   K == "Rooms" -> number_string(N, V), I1 = I0.put(rooms_count, N)
    ;   K == "Days" -> number_string(N, V), I1 = I0.put(days, N)
    ;   K == "Periods_per_day" -> number_string(N, V), I1 = I0.put(periods_per_day, N)
    ;   K == "Curricula" -> number_string(N, V), I1 = I0.put(curricula_count, N)
    ;   K == "Constraints" -> number_string(N, V), I1 = I0.put(constraints_count, N)
    ;   true -> I1 = I0
    ),
    header_to_instance(Rest, I1, I).

% -------------------------
% Official ITC2007 format
% -------------------------

parse_sections_official(Lines, I0, I) :-
    expect_label("COURSES:", Lines, AfterCoursesLabel),
    take_n(I0, courses, AfterCoursesLabel, CourseLines, AfterCourses),
    foldl(parse_course, CourseLines, I0, I1),
    expect_label("ROOMS:", AfterCourses, AfterRoomsLabel),
    take_n(I0, rooms, AfterRoomsLabel, RoomLines, AfterRooms),
    foldl(parse_room, RoomLines, I1, I2),
    expect_label("CURRICULA:", AfterRooms, AfterCurrLabel),
    take_n(I0, curricula, AfterCurrLabel, CurrLines, AfterCurr),
    foldl(parse_curriculum, CurrLines, I2, I3),
    expect_label("UNAVAILABILITY_CONSTRAINTS:", AfterCurr, AfterUnavLabel),
    take_n(I0, constraints, AfterUnavLabel, UnavLines, AfterUnav),
    foldl(parse_unav, UnavLines, I3, I4),
    (   member("END.", AfterUnav)
    ->  true
    ;   true
    ),
    reverse_instance_lists(I4, I).

expect_label(Label, [Label|Rest], Rest) :- !.
expect_label(Label, [Line|Rest0], Rest) :-
    % tolerate stray whitespace by normalizing
    normalize_space(string(Norm), Line),
    normalize_space(string(NormLabel), Label),
    Norm == NormLabel,
    !,
    Rest = Rest0.
expect_label(Label, [Line|_], _) :-
    format(user_error, 'Expected label ~w but found ~w~n', [Label, Line]),
    fail.
expect_label(Label, [], _) :-
    format(user_error, 'Expected label ~w but reached EOF~n', [Label]),
    fail.

% Take exactly N lines according to header counts.
take_n(I, courses, Lines, Taken, Rest) :-
    get_dict(courses_count, I, N),
    take_exact(N, Lines, Taken, Rest).
take_n(I, rooms, Lines, Taken, Rest) :-
    get_dict(rooms_count, I, N),
    take_exact(N, Lines, Taken, Rest).
take_n(I, curricula, Lines, Taken, Rest) :-
    get_dict(curricula_count, I, N),
    take_exact(N, Lines, Taken, Rest).
take_n(I, constraints, Lines, Taken, Rest) :-
    get_dict(constraints_count, I, N),
    take_exact(N, Lines, Taken, Rest).

take_exact(0, Lines, [], Lines) :- !.
take_exact(N, [X|Xs], [X|Ys], Rest) :-
    N > 0,
    N1 is N - 1,
    take_exact(N1, Xs, Ys, Rest).
take_exact(N, [], _, _) :-
    format(user_error, 'Unexpected EOF while taking ~d lines~n', [N]),
    fail.

parse_course(Line, I0, I) :-
    split_string(Line, " \t", " \t", [C,T,Ls,MDs,Ss]),
    number_string(L, Ls),
    number_string(MD, MDs),
    number_string(S, Ss),
    model:add_course(I0, course(C,T,L,MD,S), I).

parse_room(Line, I0, I) :-
    split_string(Line, " \t", " \t", [R,Cs]),
    number_string(C, Cs),
    model:add_room(I0, room(R,C), I).

parse_curriculum(Line, I0, I) :-
    split_string(Line, " \t", " \t", [CurrId, CountStr|Courses]),
    number_string(Count, CountStr),
    length(Courses, Count),
    model:add_curriculum(I0, curriculum(CurrId, Courses), I).

parse_unav(Line, I0, I) :-
    split_string(Line, " \t", " \t", [C,Ds,Ps]),
    number_string(D, Ds),
    number_string(P, Ps),
    model:add_unavailability(I0, C, D, P, I).
