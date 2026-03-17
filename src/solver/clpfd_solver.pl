:- module(clpfd_solver, [construct/2]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).

% Simple CLPFD model for learners:
% - one slot variable per lecture
% - one room variable per lecture
% - pairwise hard constraints between lectures

construct(Instance, Solution) :-
    build_lectures(Instance.courses, Lectures),
    length(Lectures, N),
    length(SlotVars, N),
    length(RoomVars, N),
    NumSlots is Instance.days * Instance.periods_per_day,
    length(Instance.rooms, NumRooms),
    NumSlots > 0,
    NumRooms > 0,
    MaxSlot is NumSlots - 1,
    SlotVars ins 0..MaxSlot,
    RoomVars ins 1..NumRooms,
    constrain_unavailability(Lectures, SlotVars, Instance.unavailability,
        Instance.periods_per_day),
    constrain_pairs(Lectures, SlotVars, RoomVars, Instance.curricula),
    append(SlotVars, RoomVars, Vars),
    labeling([ffc], Vars),
    build_solution(Lectures, SlotVars, RoomVars, Instance.rooms,
        Instance.periods_per_day, Solution).

build_lectures(Courses, Lectures) :-
    findall(lecture(Course, LectureIndex, Teacher),
        ( member(course(Course, Teacher, LectureCount, _MinDays, _Students), Courses),
          LectureCount > 0,
          MaxIndex is LectureCount - 1,
          between(0, MaxIndex, LectureIndex)
        ),
        Lectures).

constrain_unavailability([], [], _Unavailability, _PeriodsPerDay).
constrain_unavailability([lecture(Course, _LectureIndex, _Teacher)|Lectures],
        [Slot|Slots], Unavailability, PeriodsPerDay) :-
    constrain_course_unavailability(Course, Slot, Unavailability, PeriodsPerDay),
    constrain_unavailability(Lectures, Slots, Unavailability, PeriodsPerDay).

constrain_course_unavailability(_Course, _Slot, [], _PeriodsPerDay).
constrain_course_unavailability(Course, Slot,
        [unavailable(UnavailableCourse, Day, Period)|Rest], PeriodsPerDay) :-
    (   Course == UnavailableCourse
    ->  ForbiddenSlot is Day * PeriodsPerDay + Period,
        Slot #\= ForbiddenSlot
    ;   true
    ),
    constrain_course_unavailability(Course, Slot, Rest, PeriodsPerDay).

constrain_pairs([], [], [], _Curricula).
constrain_pairs([Lecture|Lectures], [Slot|Slots], [Room|Rooms], Curricula) :-
    constrain_with_rest(Lecture, Slot, Room, Lectures, Slots, Rooms, Curricula),
    constrain_pairs(Lectures, Slots, Rooms, Curricula).

constrain_with_rest(_Lecture, _Slot, _Room, [], [], [], _Curricula).
constrain_with_rest(lecture(Course1, LectureIndex1, Teacher1), Slot1, Room1,
        [lecture(Course2, _LectureIndex2, Teacher2)|Lectures], [Slot2|Slots],
        [Room2|Rooms], Curricula) :-
    % Same course: two lectures cannot be in the same slot.
    (   Course1 == Course2
    ->  Slot1 #\= Slot2
    ;   true
    ),
    % Same teacher: courses taught by the same teacher cannot overlap.
    (   Course1 \== Course2,
        Teacher1 == Teacher2
    ->  Slot1 #\= Slot2
    ;   true
    ),
    % Same curriculum: courses in one curriculum cannot overlap.
    (   Course1 \== Course2,
        share_curriculum(Course1, Course2, Curricula)
    ->  Slot1 #\= Slot2
    ;   true
    ),
    % Room conflict: same room cannot host two lectures in one slot.
    (Slot1 #\= Slot2) #\/ (Room1 #\= Room2),
    constrain_with_rest(lecture(Course1, LectureIndex1, Teacher1), Slot1, Room1,
        Lectures, Slots, Rooms, Curricula).

share_curriculum(Course1, Course2, Curricula) :-
    member(curriculum(_CurriculumId, Courses), Curricula),
    memberchk(Course1, Courses),
    memberchk(Course2, Courses),
    !.

build_solution([], [], [], _Rooms, _PeriodsPerDay, []).
build_solution([lecture(Course, LectureIndex, _Teacher)|Lectures], [Slot|Slots],
        [RoomVar|RoomVars], Rooms, PeriodsPerDay,
        [assignment(Course, LectureIndex, Day, Period, RoomId)|Solution]) :-
    Day is Slot // PeriodsPerDay,
    Period is Slot mod PeriodsPerDay,
    nth1(RoomVar, Rooms, room(RoomId, _Capacity)),
    build_solution(Lectures, Slots, RoomVars, Rooms, PeriodsPerDay, Solution).
