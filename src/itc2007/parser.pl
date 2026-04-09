:- module(parser, [read_instance/2]). % Declare the 'parser' module, exporting read_instance/2.

:- use_module(library(readutil)). % Import readutil for read_stream_to_codes/2 (file → code list).
:- use_module(library(lists)).    % Import lists for reverse/2 used when re-ordering parsed sections.
:- use_module(library(apply)).    % Import apply for foldl/4 used to fold parsing over line lists.
:- use_module(model).             % Import the model module for empty_instance/1 and add_*/N predicates.

% read_instance(+Path, -Instance)
% Read an ITC2007 Track-2 .ctt file at Path and unify Instance with the populated instance dict.
read_instance(Path, Instance) :-
    setup_call_cleanup(         % Open the file safely; close stream even on failure or exception.
        open(Path, read, S),    % Open Path for reading, binding stream handle to S.
        read_stream_to_codes(S, Codes), % Read all bytes of the stream into a list of character codes.
        close(S)                % Always close the stream after reading (resource cleanup).
    ),
    atom_codes(Atom, Codes),            % Convert the code list to a Prolog atom for string operations.
    split_string(Atom, "\n", "\r", Lines0), % Split the atom on newline characters into a list of strings.
    filter_blank_lines(Lines0, Lines),  % Remove empty or whitespace-only lines from the list.
    parse_header(Lines, AfterHeader, I0), % Parse the header key-value pairs and build the initial instance dict.
    parse_sections_official(AfterHeader, I0, Instance). % Parse the four data sections into the complete instance.

% filter_blank_lines(+Lines, -NonBlank)
% Remove any line that consists entirely of spaces and tabs.
filter_blank_lines([], []).                   % Base case: empty input produces empty output.
filter_blank_lines([L|Ls], Result) :-         % Recursive case: examine head line L.
    (   blank_line(L)                         % Test whether L contains only whitespace.
    ->  filter_blank_lines(Ls, Result)        % If blank, skip it and continue with the tail.
    ;   Result = [L|Rest],                    % Otherwise, include L in the result list.
        filter_blank_lines(Ls, Rest)          % Recurse to process the remaining lines.
    ).

% blank_line(+S)
% True when the string S contains only space (32) or tab (9) characters.
blank_line(S) :-
    string_codes(S, Codes),           % Convert string S to a list of character codes.
    forall(member(C, Codes), (C=32 ; C=9)). % Every code must be space (32) or tab (9).

% parse_header(+Lines, -Rest, -Instance)
% Parse the leading key-value header lines from Lines, build the initial instance dict,
% and unify Rest with the remaining lines (starting with the COURSES: label).
parse_header(Lines, Rest, I) :-
    model:empty_instance(I0),         % Create a blank instance dict as the accumulator.
    take_kv(Lines, HeaderKVs, Rest0), % Extract all "Key: Value" lines at the front of Lines.
    header_to_instance(HeaderKVs, I0, I1), % Fold the key-value pairs into the instance dict.
    reverse_instance_lists(I1, I),    % Reverse lists accumulated in reverse order to restore original order.
    Rest = Rest0.                     % Bind Rest to the remaining non-header lines.

% reverse_instance_lists(+I0, -I)
% Reverse the four list fields (courses, rooms, curricula, unavailability) in the dict
% so that elements appear in the file order rather than prepend order.
reverse_instance_lists(I0, I) :-
    reverse(I0.courses, Courses),         % Reverse courses list to file order.
    reverse(I0.rooms, Rooms),             % Reverse rooms list to file order.
    reverse(I0.curricula, Curricula),     % Reverse curricula list to file order.
    reverse(I0.unavailability, Unav),     % Reverse unavailability list to file order.
    I = I0.put(_{courses:Courses, rooms:Rooms, curricula:Curricula, unavailability:Unav}). % Update all four keys at once.

% Take initial lines formatted as "Key: Value" until a non-matching line.
take_kv([L|Ls], [K=V|KVs], Rest) :-    % Match when the next line L is a valid "K: V" pair.
    split_string(L, ":", " ", [K0|Vs]),  % Split on ':' (with space trim), first part is key.
    Vs \= [],                            % Ensure there is at least a value part after ':'.
    normalize_space(string(K), K0),      % Strip leading/trailing whitespace from the key string.
    atomic_list_concat(Vs, ':', VAtom),  % Re-join value parts (handles values containing ':').
    atom_string(VAtom, VStr0),           % Convert the joined value atom to a string.
    normalize_space(string(V), VStr0),   % Strip whitespace from the value string.
    V \= "",                             % Ensure the value is non-empty (skip bare "Key:" lines).
    !,                                   % Commit: this line is a valid header pair, stop backtracking.
    take_kv(Ls, KVs, Rest).             % Recurse to collect remaining header pairs from the tail.
take_kv(Rest, [], Rest).                % Base case: no more "K: V" lines; return remaining lines unchanged.

% header_to_instance(+KVs, +I0, -I)
% Fold a list of K=V pairs into the instance dict, populating the matching fields.
header_to_instance([], I, I).           % Base case: no more pairs; instance dict is unchanged.
header_to_instance([K=V|Rest], I0, I) :- % Recursive case: process one K=V pair.
    (   K == "Name" -> I1 = I0.put(name, V)        % "Name" field: store the string value directly.
    ;   K == "Courses" -> number_string(N, V), I1 = I0.put(courses_count, N) % Parse integer courses count.
    ;   K == "Rooms" -> number_string(N, V), I1 = I0.put(rooms_count, N)     % Parse integer rooms count.
    ;   K == "Days" -> number_string(N, V), I1 = I0.put(days, N)             % Parse integer days count.
    ;   K == "Periods_per_day" -> number_string(N, V), I1 = I0.put(periods_per_day, N) % Parse integer periods.
    ;   K == "Curricula" -> number_string(N, V), I1 = I0.put(curricula_count, N)       % Parse curricula count.
    ;   K == "Constraints" -> number_string(N, V), I1 = I0.put(constraints_count, N)   % Parse constraint count.
    ;   true -> I1 = I0                 % Unknown key: silently skip; instance dict is unchanged.
    ),
    header_to_instance(Rest, I1, I).    % Recurse to process the remaining key-value pairs.

% -------------------------
% Official ITC2007 format
% -------------------------

% parse_sections_official(+Lines, +I0, -Instance)
% Parse the four mandatory sections (COURSES, ROOMS, CURRICULA,
% UNAVAILABILITY_CONSTRAINTS) from Lines, building on instance I0 to produce Instance.
parse_sections_official(Lines, I0, I) :-
    expect_label("COURSES:", Lines, AfterCoursesLabel),    % Consume the "COURSES:" label line.
    take_n(I0, courses, AfterCoursesLabel, CourseLines, AfterCourses), % Read exactly courses_count lines.
    foldl(parse_course, CourseLines, I0, I1),              % Parse each course line and add to dict.
    expect_label("ROOMS:", AfterCourses, AfterRoomsLabel), % Consume the "ROOMS:" label line.
    take_n(I0, rooms, AfterRoomsLabel, RoomLines, AfterRooms), % Read exactly rooms_count lines.
    foldl(parse_room, RoomLines, I1, I2),                  % Parse each room line and add to dict.
    expect_label("CURRICULA:", AfterRooms, AfterCurrLabel),% Consume the "CURRICULA:" label line.
    take_n(I0, curricula, AfterCurrLabel, CurrLines, AfterCurr), % Read exactly curricula_count lines.
    foldl(parse_curriculum, CurrLines, I2, I3),            % Parse each curriculum line and add to dict.
    expect_label("UNAVAILABILITY_CONSTRAINTS:", AfterCurr, AfterUnavLabel), % Consume unavailability label.
    take_n(I0, constraints, AfterUnavLabel, UnavLines, AfterUnav), % Read exactly constraints_count lines.
    foldl(parse_unav, UnavLines, I3, I4),                  % Parse each unavailability line and add to dict.
    (   member("END.", AfterUnav)  % Check whether the optional END. marker is present in remaining lines.
    ->  true                       % If present, succeed (we accept but do not require it).
    ;   true                       % If absent, also succeed (END. is optional in our parser).
    ),
    reverse_instance_lists(I4, I). % Reverse accumulated lists to restore file-order ordering.

% expect_label(+Label, +Lines, -Rest)
% Consume the expected section label from the front of Lines, unifying Rest with the tail.
expect_label(Label, [Label|Rest], Rest) :- !. % Fast match: head equals label exactly; commit.
expect_label(Label, [Line|Rest0], Rest) :-    % Slow match: try normalised comparison for whitespace tolerance.
    % tolerate stray whitespace by normalizing
    normalize_space(string(Norm), Line),       % Normalise whitespace in the actual line.
    normalize_space(string(NormLabel), Label), % Normalise whitespace in the expected label.
    Norm == NormLabel,                         % Succeed only if normalised forms are equal.
    !,                                         % Commit: found the label after normalisation.
    Rest = Rest0.                              % Bind Rest to the tail of Lines.
expect_label(Label, [Line|_], _) :-           % Error case: head line does not match the expected label.
    format(user_error, 'Expected label ~w but found ~w~n', [Label, Line]), % Report mismatch to stderr.
    fail.                                      % Fail to propagate the error upward.
expect_label(Label, [], _) :-                 % Error case: reached end of input before finding the label.
    format(user_error, 'Expected label ~w but reached EOF~n', [Label]), % Report EOF error to stderr.
    fail.                                     % Fail to propagate the error upward.

% Take exactly N lines according to header counts.
take_n(I, courses, Lines, Taken, Rest) :-    % take_n for the 'courses' section.
    get_dict(courses_count, I, N),           % Look up how many course lines the header declared.
    take_exact(N, Lines, Taken, Rest).       % Take exactly N lines, binding Taken and remaining Rest.
take_n(I, rooms, Lines, Taken, Rest) :-      % take_n for the 'rooms' section.
    get_dict(rooms_count, I, N),             % Look up how many room lines the header declared.
    take_exact(N, Lines, Taken, Rest).       % Take exactly N lines.
take_n(I, curricula, Lines, Taken, Rest) :-  % take_n for the 'curricula' section.
    get_dict(curricula_count, I, N),         % Look up how many curriculum lines the header declared.
    take_exact(N, Lines, Taken, Rest).       % Take exactly N lines.
take_n(I, constraints, Lines, Taken, Rest) :- % take_n for the 'unavailability_constraints' section.
    get_dict(constraints_count, I, N),       % Look up how many constraint lines the header declared.
    take_exact(N, Lines, Taken, Rest).       % Take exactly N lines.

% take_exact(+N, +Lines, -Taken, -Rest)
% Unify Taken with the first N elements of Lines and Rest with the remainder.
take_exact(0, Lines, [], Lines) :- !.        % Base case: 0 lines to take; Taken is empty, Lines unchanged.
take_exact(N, [X|Xs], [X|Ys], Rest) :-      % Recursive case: take one line X from the front.
    N > 0,                                   % Guard: N must be positive.
    N1 is N - 1,                             % Decrement the remaining count by 1.
    take_exact(N1, Xs, Ys, Rest).            % Recurse: take N1 more lines from the tail Xs.
take_exact(N, [], _, _) :-                  % Error case: reached end of input while still needing N lines.
    format(user_error, 'Unexpected EOF while taking ~d lines~n', [N]), % Report unexpected EOF to stderr.
    fail.                                   % Fail to propagate the parse error upward.

% parse_course(+Line, +I0, -I)
% Parse a single course line "CourseId TeacherId Lectures MinDays Students" and add the course to I0.
parse_course(Line, I0, I) :-
    split_string(Line, " \t", " \t", [C,T,Ls,MDs,Ss]), % Split on whitespace into exactly 5 tokens.
    number_string(L, Ls),    % Convert the lectures count string to a number.
    number_string(MD, MDs),  % Convert the minimum working days string to a number.
    number_string(S, Ss),    % Convert the students count string to a number.
    model:add_course(I0, course(C,T,L,MD,S), I). % Create course/5 term and prepend it to the instance.

% parse_room(+Line, +I0, -I)
% Parse a single room line "RoomId Capacity" and add the room to I0.
parse_room(Line, I0, I) :-
    split_string(Line, " \t", " \t", [R,Cs]), % Split on whitespace into exactly 2 tokens.
    number_string(C, Cs),                     % Convert the capacity string to a number.
    model:add_room(I0, room(R,C), I).         % Create room/2 term and prepend it to the instance.

% parse_curriculum(+Line, +I0, -I)
% Parse a single curriculum line "CurrId Count CourseId..." and add the curriculum to I0.
parse_curriculum(Line, I0, I) :-
    split_string(Line, " \t", " \t", [CurrId, CountStr|Courses]), % First token is ID, second is count, rest are course IDs.
    number_string(Count, CountStr),           % Convert count string to a number.
    length(Courses, Count),                   % Validate that exactly Count course IDs follow.
    model:add_curriculum(I0, curriculum(CurrId, Courses), I). % Create curriculum/2 term and add it.

% parse_unav(+Line, +I0, -I)
% Parse a single unavailability line "CourseId Day Period" and add the constraint to I0.
parse_unav(Line, I0, I) :-
    split_string(Line, " \t", " \t", [C,Ds,Ps]), % Split on whitespace into exactly 3 tokens.
    number_string(D, Ds),                        % Convert day string to a number.
    number_string(P, Ps),                        % Convert period string to a number.
    model:add_unavailability(I0, C, D, P, I).    % Create unavailable/3 term and prepend it to the instance.
