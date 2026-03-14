:- module(constructive, [construct/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(random)).
:- use_module(library(assoc)).

% Simple greedy construction:
% Assign each lecture to the first available (day,period,room) that does not
% violate teacher/room/curriculum/unavailability. Good enough for tiny fixtures.

construct(Instance, Solution) :-
    Days is Instance.days,
    Periods is Instance.periods_per_day,
    MaxD is Days - 1,
    MaxP is Periods - 1,
    findall(slot(D,P), (between(0, MaxD, D), between(0, MaxP, P)), Slots0),
    random_permutation(Slots0, Slots),
    Instance.rooms = Rooms0,
    random_permutation(Rooms0, Rooms),
    build_teacher_map(Instance.courses, TeacherMap),
    build_course_curricula_map(Instance.curricula, CurrMap),
    build_tasks(Instance, CurrMap, Tasks),
    try_attempts(30, Instance, Rooms, Slots, TeacherMap, CurrMap, Tasks, Solution).

try_attempts(0, _Instance, _Rooms, _Slots, _TeacherMap, _CurrMap, _Tasks, _Solution) :-
    !,
    fail.
try_attempts(AttemptsLeft, Instance, Rooms0, Slots0, TeacherMap, CurrMap, Tasks0, Solution) :-
    random_permutation(Rooms0, Rooms),
    random_permutation(Slots0, Slots),
    random_permutation(Tasks0, Tasks),
    (   schedule_tasks(Tasks, Instance, Rooms, Slots, TeacherMap, CurrMap, [], Solution)
    ->  !
    ;   Attempts1 is AttemptsLeft - 1,
        try_attempts(Attempts1, Instance, Rooms0, Slots0, TeacherMap, CurrMap, Tasks0, Solution)
    ).

% Build tasks = one per lecture, with a simple difficulty ordering.
% Each task is task(Course, LectureIndex).
build_tasks(Instance, CurrMap, TasksSorted) :-
    findall(task(Course, I),
        ( member(course(Course, _T, Lectures, _MD, _S), Instance.courses),
          Lectures > 0,
          MaxI is Lectures - 1,
          between(0, MaxI, I)
        ),
        Tasks),
    map_list_to_pairs(task_weight(Instance, CurrMap), Tasks, Pairs),
    keysort(Pairs, SortedPairsAsc),
    reverse(SortedPairsAsc, SortedPairsDesc),
    pairs_values(SortedPairsDesc, TasksSorted).

task_weight(Instance, CurrMap, task(Course, _I), W) :-
    % Higher weight = schedule earlier.
    findall(1, member(unavailable(Course, _D, _P), Instance.unavailability), Unav),
    length(Unav, UnavCount),
    ( get_assoc(Course, CurrMap, Currs) -> length(Currs, CurrCount) ; CurrCount = 0 ),
    W is UnavCount + CurrCount.

schedule_tasks([], _Instance, _Rooms, _Slots, _TeacherMap, _CurrMap, Sol, Sol).
schedule_tasks([task(Course, LectureIndex)|Rest], Instance, Rooms, Slots, TeacherMap, CurrMap, Acc, Solution) :-
    place_greedy(Course, LectureIndex, Instance, Rooms, Slots, TeacherMap, CurrMap, Acc, Acc1),
    schedule_tasks(Rest, Instance, Rooms, Slots, TeacherMap, CurrMap, Acc1, Solution).

place_greedy(Course, LectureIndex, Instance, Rooms, Slots, TeacherMap, CurrMap, Acc,
             [assignment(Course, LectureIndex, Day, Period, RoomId)|Acc]) :-
    member(slot(Day, Period), Slots),
    member(room(RoomId, _Cap), Rooms),
    can_place(Course, Day, Period, RoomId, Instance, TeacherMap, CurrMap, Acc),
    !.

can_place(Course, Day, Period, RoomId, Instance, TeacherMap, CurrMap, Acc) :-
    % Unavailability
    \+ memberchk(unavailable(Course, Day, Period), Instance.unavailability),
    % Same course not twice in same slot
    \+ memberchk(assignment(Course, _I, Day, Period, _R), Acc),
    % Room conflict
    \+ memberchk(assignment(_OC, _OI, Day, Period, RoomId), Acc),
    % Teacher conflict
    ( get_assoc(Course, TeacherMap, Teacher) -> true ; Teacher = '' ),
    \+ ( member(assignment(OtherCourse, _OJ, Day, Period, _OR), Acc),
         OtherCourse \= Course,
         get_assoc(OtherCourse, TeacherMap, Teacher)
       ),
    % Curriculum conflict
    ( get_assoc(Course, CurrMap, CourseCurrs) -> true ; CourseCurrs = [] ),
    \+ ( member(assignment(OtherCourse, _OK, Day, Period, _RR), Acc),
         OtherCourse \= Course,
         get_assoc(OtherCourse, CurrMap, OtherCurrs),
         intersects(CourseCurrs, OtherCurrs)
       ).

intersects([X|_], Ys) :- memberchk(X, Ys), !.
intersects([_|Xs], Ys) :- intersects(Xs, Ys).

build_teacher_map(Courses, Assoc) :-
    empty_assoc(A0),
    foldl(put_teacher, Courses, A0, Assoc).

put_teacher(course(Course, Teacher, _L, _MD, _S), A0, A) :-
    put_assoc(Course, A0, Teacher, A).

build_course_curricula_map(Curricula, Assoc) :-
    empty_assoc(A0),
    foldl(put_curriculum, Curricula, A0, Assoc).

put_curriculum(curriculum(CurrId, Courses), A0, A) :-
    foldl(add_course_to_curr(CurrId), Courses, A0, A).

add_course_to_curr(CurrId, Course, A0, A) :-
    (   get_assoc(Course, A0, Currs0)
    ->  ( memberchk(CurrId, Currs0) -> Currs = Currs0 ; Currs = [CurrId|Currs0] ),
        put_assoc(Course, A0, Currs, A)
    ;   put_assoc(Course, A0, [CurrId], A)
    ).
