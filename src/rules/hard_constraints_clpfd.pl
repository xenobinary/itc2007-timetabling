:- module(hard_constraints_clpfd, [
    feasible_clpfd/2,
    violates_clpfd/3
]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).
:- use_module(library(assoc)).

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
    \+ violates_clpfd(Instance, Solution, _).

%! violates_clpfd(+Instance, +Solution, -Reason) is semidet
% True when Solution violates at least one hard constraint.
% Reason is a term describing the first violation found.
violates_clpfd(Instance, Solution, Reason) :-
    ( violates_lecture_count_clpfd(Instance, Solution, Reason)
    ; violates_room_conflict_clpfd(Instance, Solution, Reason)
    ; violates_course_conflict_clpfd(Instance, Solution, Reason)
    ; violates_teacher_conflict_clpfd(Instance, Solution, Reason)
    ; violates_curriculum_conflict_clpfd(Instance, Solution, Reason)
    ; violates_unavailability_clpfd(Instance, Solution, Reason)
    ),
    !.

% ---- 1. Lecture count --------------------------------------------------
% Every course must have exactly the right number of distinct lecture slots.

violates_lecture_count_clpfd(Instance, Solution, missing_lecture(Course)) :-
    member(course(Course, _T, Lectures, _MD, _S), Instance.courses),
    findall(I, member(assignment(Course, I, _D, _P, _R), Solution), Is),
    sort(Is, Unique),
    length(Unique, N),
    N #\= Lectures.

% ---- 2. Room conflict (CLP(FD) all_different) --------------------------
% Encode each assignment as (Day*Periods + Period)*NumRooms + RoomIdx.
% Duplicate codes mean two assignments share the same room at the same time.

violates_room_conflict_clpfd(Instance, Solution, room_conflict(Day,Period,Room)) :-
    Periods = Instance.periods_per_day,
    length(Instance.rooms, NumRooms),
    build_room_idx_map(Instance.rooms, RoomIdxMap),
    maplist(slot_room_code(Periods, NumRooms, RoomIdxMap), Solution, Codes),
    \+ all_different(Codes),
    select(assignment(_,_,Day,Period,Room), Solution, Rest),
    member(assignment(_,_,Day,Period,Room), Rest).

% ---- 3. Course conflict (CLP(FD) all_different per course) -------------
% Each course's lectures must occupy distinct time slots.

violates_course_conflict_clpfd(Instance, Solution, course_conflict(Course,Day,Period)) :-
    Periods = Instance.periods_per_day,
    member(course(Course, _, _, _, _), Instance.courses),
    findall(S,
        ( member(assignment(Course, _, D, P, _), Solution),
          S #= D * Periods + P
        ),
        Slots),
    \+ all_different(Slots),
    member(assignment(Course, I1, Day, Period, _), Solution),
    member(assignment(Course, I2, Day, Period, _), Solution),
    I1 #\= I2.

% ---- 4. Teacher conflict -----------------------------------------------
% Two courses taught by the same teacher may not share a time slot.

violates_teacher_conflict_clpfd(Instance, Solution,
                                teacher_conflict(Teacher,Day,Period)) :-
    course_teacher_clpfd(Instance, C1, Teacher),
    course_teacher_clpfd(Instance, C2, Teacher),
    C1 \= C2,
    member(assignment(C1, _, Day, Period, _), Solution),
    member(assignment(C2, _, Day, Period, _), Solution).

% ---- 5. Curriculum conflict --------------------------------------------
% Two courses in the same curriculum may not share a time slot.

violates_curriculum_conflict_clpfd(Instance, Solution,
                                   curriculum_conflict(Curr,Day,Period)) :-
    member(curriculum(Curr, Courses), Instance.curricula),
    member(C1, Courses),
    member(C2, Courses),
    C1 \= C2,
    member(assignment(C1, _, Day, Period, _), Solution),
    member(assignment(C2, _, Day, Period, _), Solution).

% ---- 6. Unavailability -------------------------------------------------
% A course must not be assigned to a forbidden (day, period).
% The time slot of the assignment is compared to the forbidden slot via #=.

violates_unavailability_clpfd(Instance, Solution,
                              unavailability(Course,Day,Period)) :-
    Periods = Instance.periods_per_day,
    member(unavailable(Course, Day, Period), Instance.unavailability),
    UnavSlot #= Day * Periods + Period,
    member(assignment(Course, _, AD, AP, _), Solution),
    AssignSlot #= AD * Periods + AP,
    AssignSlot #= UnavSlot.

% ---- Helpers -----------------------------------------------------------

course_teacher_clpfd(Instance, Course, Teacher) :-
    member(course(Course, Teacher, _, _, _), Instance.courses).

%! build_room_idx_map(+Rooms, -Map) is det
% Map is an assoc mapping each room ID to its 0-based index in Rooms.
build_room_idx_map(Rooms, Map) :-
    length(Rooms, N), Max is N - 1,
    findall(RoomId-Idx,
        ( between(0, Max, Idx),
          nth0(Idx, Rooms, room(RoomId, _))
        ),
        Pairs),
    list_to_assoc(Pairs, Map).

%! slot_room_code(+Periods, +NumRooms, +RoomIdxMap, +Assignment, -Code) is det
% Code is the unique integer encoding for Assignment.
slot_room_code(Periods, NumRooms, RoomIdxMap,
               assignment(_, _, Day, Period, RoomId), Code) :-
    get_assoc(RoomId, RoomIdxMap, RI),
    Code #= (Day * Periods + Period) * NumRooms + RI.
