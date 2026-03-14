:- module(soft_constraints, [penalty/3]).

:- use_module(library(lists)).

% Soft constraints (Track 2 - Curriculum-based Course Timetabling):
% - Room capacity (weight: 1)
% - Minimum working days (weight: 5)
% - Curriculum compactness (weight: 2)
% - Room stability (weight: 1)

penalty(Instance, Solution, TotalPenalty) :-
    room_capacity_penalty(Instance, Solution, RoomCapPenalty),
    min_working_days_penalty(Instance, Solution, MinDaysPenalty),
    curriculum_compactness_penalty(Instance, Solution, CompactPenalty),
    room_stability_penalty(Instance, Solution, StabilityPenalty),
    TotalPenalty is RoomCapPenalty + MinDaysPenalty + CompactPenalty + StabilityPenalty.

% -----------------------------------------------------------------------------
% Room Capacity: For each lecture, students > room capacity contributes 1 per student
% Weight: 1
% -----------------------------------------------------------------------------
room_capacity_penalty(Instance, Solution, Penalty) :-
    findall(P, (
        member(assignment(Course, _LectureIdx, _Day, _Period, RoomId), Solution),
        member(course(Course, _Teacher, _Lectures, _MinDays, Students), Instance.courses),
        member(room(RoomId, Capacity), Instance.rooms),
        Students > Capacity,
        P is Students - Capacity
    ), Violations),
    sum_list(Violations, Penalty).

% -----------------------------------------------------------------------------
% Minimum Working Days: lectures should be spread over minDays days
% Weight: 5 per day below minimum
% -----------------------------------------------------------------------------
min_working_days_penalty(Instance, Solution, Penalty) :-
    findall(P, (
        member(course(Course, _Teacher, _Lectures, MinDays, _Students), Instance.courses),
        MinDays > 0,
        findall(Day, member(assignment(Course, _I, Day, _Period, _R), Solution), Days0),
        sort(Days0, Days),
        length(Days, ActualDays),
        ActualDays < MinDays,
        P is (MinDays - ActualDays) * 5
    ), Violations),
    sum_list(Violations, Penalty).

% -----------------------------------------------------------------------------
% Curriculum Compactness: lectures in same curriculum should be adjacent
% Weight: 2 per isolated lecture
% An isolated lecture is one not adjacent to any other lecture in the same day
% -----------------------------------------------------------------------------
curriculum_compactness_penalty(Instance, Solution, Penalty) :-
    findall(P, (
        member(curriculum(_CurriculumId, Courses), Instance.curricula),
        curriculum_isolated_count(Courses, Solution, NumIsolated),
        NumIsolated > 0,
        P is NumIsolated * 2
    ), Violations),
    sum_list(Violations, Penalty).

curriculum_isolated_count(Courses, Solution, NumIsolated) :-
    findall(d(D)-p(P), (
        member(Course, Courses),
        member(assignment(Course, _L, D, P, _R), Solution)
    ), AllDPs),
    sort(AllDPs, SortedDPs),
    count_isolated(SortedDPs, 0, NumIsolated).

count_isolated([], Acc, Acc).
count_isolated([d(D)-p(P)|Rest], Acc, Total) :-
    ( member(d(D)-p(P1), Rest),
      (P1 is P + 1 ; P1 is P - 1)
    ->  count_isolated(Rest, Acc, Total)
    ;   NewAcc is Acc + 1,
        count_isolated(Rest, NewAcc, Total)
    ).

% -----------------------------------------------------------------------------
% Room Stability: all lectures of a course should be in the same room
% Weight: 1 per extra room used
% -----------------------------------------------------------------------------
room_stability_penalty(Instance, Solution, Penalty) :-
    findall(P, (
        member(course(Course, _Teacher, Lectures, _MinDays, _Students), Instance.courses),
        Lectures > 0,
        findall(RoomId, member(assignment(Course, _I, _D, _P, RoomId), Solution), Rooms0),
        sort(Rooms0, Rooms),
        length(Rooms, NumRooms),
        NumRooms > 1,
        P is NumRooms - 1
    ), Violations),
    sum_list(Violations, Penalty).
