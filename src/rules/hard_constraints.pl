:- module(hard_constraints, [
    feasible/2,
    violates/3,
    violates_partial/3
]).

:- use_module(library(lists)).

% Core hard constraints for ITC2007 Track 2 (simplified):
% - all lectures scheduled
% - no room conflicts
% - no teacher conflicts
% - no curriculum conflicts
% - no unavailability violations

feasible(Instance, Solution) :-
    \+ violates(Instance, Solution, _).

violates(Instance, Solution, Reason) :-
    ( violates_lecture_count(Instance, Solution, Reason)
    ; violates_partial(Instance, Solution, Reason)
    ),
    !.

% Partial violations used while constructing a timetable.
% Omits lecture-count completeness because the solution is still being built.
violates_partial(Instance, Solution, Reason) :-
    ( violates_room_conflict(Solution, Reason)
    ; violates_course_conflict(Solution, Reason)
    ; violates_teacher_conflict(Instance, Solution, Reason)
    ; violates_curriculum_conflict(Instance, Solution, Reason)
    ; violates_unavailability(Instance, Solution, Reason)
    ),
    !.

violates_lecture_count(Instance, Solution, missing_lecture(Course)) :-
    member(course(Course, _Teacher, Lectures, _MinDays, _Students), Instance.courses),
    findall(I, member(assignment(Course, I, _D, _P, _R), Solution), Is),
    sort(Is, Unique),
    length(Unique, N),
    N =\= Lectures.

violates_room_conflict(Solution, room_conflict(Day,Period,Room)) :-
    member(assignment(C1, _I1, Day, Period, Room), Solution),
    member(assignment(C2, _I2, Day, Period, Room), Solution),
    C1 \= C2.

violates_course_conflict(Solution, course_conflict(Course,Day,Period)) :-
    member(assignment(Course, I1, Day, Period, _R1), Solution),
    member(assignment(Course, I2, Day, Period, _R2), Solution),
    I1 \= I2.

violates_teacher_conflict(Instance, Solution, teacher_conflict(Teacher,Day,Period)) :-
    course_teacher(Instance, C1, Teacher),
    course_teacher(Instance, C2, Teacher),
    C1 \= C2,
    member(assignment(C1, _I1, Day, Period, _R1), Solution),
    member(assignment(C2, _I2, Day, Period, _R2), Solution).

violates_curriculum_conflict(Instance, Solution, curriculum_conflict(Curr,Day,Period)) :-
    member(curriculum(Curr, Courses), Instance.curricula),
    member(C1, Courses),
    member(C2, Courses),
    C1 \= C2,
    member(assignment(C1, _I1, Day, Period, _R1), Solution),
    member(assignment(C2, _I2, Day, Period, _R2), Solution).

violates_unavailability(Instance, Solution, unavailability(Course,Day,Period)) :-
    member(unavailable(Course,Day,Period), Instance.unavailability),
    member(assignment(Course, _I, Day, Period, _R), Solution).

course_teacher(Instance, Course, Teacher) :-
    member(course(Course, Teacher, _L, _MD, _S), Instance.courses).
