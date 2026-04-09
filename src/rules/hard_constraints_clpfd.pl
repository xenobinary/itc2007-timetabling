:- module(hard_constraints_clpfd, [  % Declare 'hard_constraints_clpfd' module, exporting:
    feasible_clpfd/2,               %   feasible_clpfd/2 — semidet feasibility check using CLP(FD).
    violates_clpfd/3                %   violates_clpfd/3 — semidet violation detector using CLP(FD).
]).

:- use_module(library(clpfd)).   % Import SWI-Prolog's CLP(FD) library for #= , #\=, all_different/1.
:- use_module(library(lists)).   % Import lists for member/2, select/3, maplist/3.
:- use_module(library(assoc)).   % Import assoc for association-list helpers (list_to_assoc, get_assoc).

% -------------------------------------------------------------------------
% ITC2007 Track 2 hard constraints using CLP(FD).
%
% Each assignment is encoded as an integer time-room code:
%   code = (Day * Periods + Period) * NumRooms + RoomIdx
% CLP(FD)'s all_different/1 detects room conflicts in one step.
% Per-course time-slot uniqueness is checked with all_different/1 too.
% Teacher and curriculum pairwise conflicts use #\= inequalities.
% -------------------------------------------------------------------------

%! feasible_clpfd(+Instance, +Solution) is semidet
% True when Solution satisfies all ITC2007 hard constraints.
feasible_clpfd(Instance, Solution) :-
    \+ violates_clpfd(Instance, Solution, _). % Succeed iff no violation term can be derived.

%! violates_clpfd(+Instance, +Solution, -Reason) is semidet
% True when Solution violates at least one hard constraint.
% Reason is a term describing the first violation found.
violates_clpfd(Instance, Solution, Reason) :-
    ( violates_lecture_count_clpfd(Instance, Solution, Reason)     % Check H1: lecture completeness.
    ; violates_room_conflict_clpfd(Instance, Solution, Reason)     % Check H2: no two courses in same room/slot.
    ; violates_course_conflict_clpfd(Instance, Solution, Reason)   % Check H3: course self-conflict.
    ; violates_teacher_conflict_clpfd(Instance, Solution, Reason)  % Check H4: teacher uniqueness per slot.
    ; violates_curriculum_conflict_clpfd(Instance, Solution, Reason) % Check H5: curriculum uniqueness per slot.
    ; violates_unavailability_clpfd(Instance, Solution, Reason)    % Check H6: no forbidden-slot assignments.
    ),
    !. % Cut: stop after detecting the first violation.

% ---- 1. Lecture count --------------------------------------------------
% Every course must have exactly the right number of distinct lecture slots.

% violates_lecture_count_clpfd(+Instance, +Solution, -missing_lecture(Course))
% Uses CLP(FD) #\= to compare the assigned count against the required count.
violates_lecture_count_clpfd(Instance, Solution, missing_lecture(Course)) :-
    member(course(Course, _T, Lectures, _MD, _S), Instance.courses), % Iterate over courses.
    findall(I, member(assignment(Course, I, _D, _P, _R), Solution), Is), % Collect assigned lecture indices.
    sort(Is, Unique),     % Deduplicate indices to count distinct lecture slots.
    length(Unique, N),    % Count distinct assigned lectures.
    N #\= Lectures.       % Violation: assigned count differs from required (CLP(FD) inequality check).

% ---- 2. Room conflict (CLP(FD) all_different) --------------------------
% Encode each assignment as (Day*Periods + Period)*NumRooms + RoomIdx.
% Duplicate codes mean two assignments share the same room at the same time.

% violates_room_conflict_clpfd(+Instance, +Solution, -room_conflict(Day,Period,Room))
% Build a unique integer code per assignment; use all_different/1 to check uniqueness.
violates_room_conflict_clpfd(Instance, Solution, room_conflict(Day,Period,Room)) :-
    Periods = Instance.periods_per_day,      % Look up the number of periods per day from instance.
    length(Instance.rooms, NumRooms),        % Count total rooms for encoding.
    build_room_idx_map(Instance.rooms, RoomIdxMap), % Build room-ID-to-index mapping.
    maplist(slot_room_code(Periods, NumRooms, RoomIdxMap), Solution, Codes), % Compute integer code per assignment.
    \+ all_different(Codes),                 % If codes are NOT all distinct, there is a room conflict.
    select(assignment(_,_,Day,Period,Room), Solution, Rest), % Find one assignment at the conflicting slot.
    member(assignment(_,_,Day,Period,Room), Rest). % Find another assignment in the same room/slot.

% ---- 3. Course conflict (CLP(FD) all_different per course) -------------
% Each course's lectures must occupy distinct time slots.

% violates_course_conflict_clpfd(+Instance, +Solution, -course_conflict(Course,Day,Period))
% For each course, collect its slot codes and check that all_different/1 holds.
violates_course_conflict_clpfd(Instance, Solution, course_conflict(Course,Day,Period)) :-
    Periods = Instance.periods_per_day,      % Number of periods per day from instance.
    member(course(Course, _, _, _, _), Instance.courses), % Iterate over all courses.
    findall(S,
        ( member(assignment(Course, _, D, P, _), Solution), % Collect each assignment for this course.
          S #= D * Periods + P                              % Encode as a flat slot number.
        ),
        Slots),
    \+ all_different(Slots),                 % Violation: two lectures in the same slot.
    member(assignment(Course, I1, Day, Period, _), Solution), % Find one conflicting assignment.
    member(assignment(Course, I2, Day, Period, _), Solution), % Find another at the same (Day,Period).
    I1 #\= I2.                              % Confirm they are different lecture indices (true conflict).

% ---- 4. Teacher conflict -----------------------------------------------
% Two courses taught by the same teacher may not share a time slot.

% violates_teacher_conflict_clpfd(+Instance, +Solution, -teacher_conflict(Teacher,Day,Period))
% Checks pairwise that no two different courses by the same teacher overlap.
violates_teacher_conflict_clpfd(Instance, Solution,
                                teacher_conflict(Teacher,Day,Period)) :-
    course_teacher_clpfd(Instance, C1, Teacher), % Find course C1 taught by Teacher.
    course_teacher_clpfd(Instance, C2, Teacher), % Find course C2 taught by the same Teacher.
    C1 \= C2,                                    % Only a conflict if the two courses are different.
    member(assignment(C1, _, Day, Period, _), Solution), % C1 is scheduled at (Day,Period).
    member(assignment(C2, _, Day, Period, _), Solution). % C2 is also at the same slot — conflict.

% ---- 5. Curriculum conflict --------------------------------------------
% Two courses in the same curriculum may not share a time slot.

% violates_curriculum_conflict_clpfd(+Instance, +Solution, -curriculum_conflict(Curr,Day,Period))
% Checks all pairs within each curriculum for time-slot overlap.
violates_curriculum_conflict_clpfd(Instance, Solution,
                                   curriculum_conflict(Curr,Day,Period)) :-
    member(curriculum(Curr, Courses), Instance.curricula), % Iterate over curricula.
    member(C1, Courses),                   % Pick a first course from the curriculum.
    member(C2, Courses),                   % Pick a second course from the same curriculum.
    C1 \= C2,                              % Conflict only between different courses.
    member(assignment(C1, _, Day, Period, _), Solution), % C1 is at (Day,Period).
    member(assignment(C2, _, Day, Period, _), Solution). % C2 is also at (Day,Period) — conflict.

% ---- 6. Unavailability -------------------------------------------------
% A course must not be assigned to a forbidden (day, period).
% The time slot of the assignment is compared to the forbidden slot via #=.

% violates_unavailability_clpfd(+Instance, +Solution, -unavailability(Course,Day,Period))
% Uses CLP(FD) #= to compare encoded slot numbers for unavailability detection.
violates_unavailability_clpfd(Instance, Solution,
                              unavailability(Course,Day,Period)) :-
    Periods = Instance.periods_per_day,         % Number of periods per day.
    member(unavailable(Course, Day, Period), Instance.unavailability), % A declared unavailable slot.
    UnavSlot #= Day * Periods + Period,          % Encode the unavailable (Day,Period) as a flat slot number.
    member(assignment(Course, _, AD, AP, _), Solution), % Find an assignment of Course.
    AssignSlot #= AD * Periods + AP,             % Encode the assigned (Day,Period) as a flat slot number.
    AssignSlot #= UnavSlot.                      % Violation: assigned slot equals the forbidden slot.

% ---- Helpers -----------------------------------------------------------

% course_teacher_clpfd(+Instance, ?Course, ?Teacher)
% Look up the Teacher of Course in the instance's courses list.
course_teacher_clpfd(Instance, Course, Teacher) :-
    member(course(Course, Teacher, _, _, _), Instance.courses). % Simple member search.

%! build_room_idx_map(+Rooms, -Map) is det
% Map is an assoc mapping each room ID to its 0-based index in Rooms.
build_room_idx_map(Rooms, Map) :-
    length(Rooms, N), Max is N - 1,       % Compute the index of the last room.
    findall(RoomId-Idx,
        ( between(0, Max, Idx),           % Iterate 0-based indices.
          nth0(Idx, Rooms, room(RoomId, _)) % Look up the room at this index.
        ),
        Pairs),
    list_to_assoc(Pairs, Map).            % Build an assoc-list for O(log n) room-ID-to-index lookup.

%! slot_room_code(+Periods, +NumRooms, +RoomIdxMap, +Assignment, -Code) is det
% Code is the unique integer encoding for Assignment combining slot and room index.
slot_room_code(Periods, NumRooms, RoomIdxMap,
               assignment(_, _, Day, Period, RoomId), Code) :-
    get_assoc(RoomId, RoomIdxMap, RI),           % Look up 0-based room index RI for RoomId.
    Code #= (Day * Periods + Period) * NumRooms + RI. % Encode: slot_number * NumRooms + room_index.
