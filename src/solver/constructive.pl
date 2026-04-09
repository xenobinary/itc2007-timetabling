:- module(constructive, [construct/2]). % Declare the 'constructive' module, exporting construct/2.

:- use_module(library(lists)).   % Import lists for member/2, reverse/2, length/2.
:- use_module(library(apply)).   % Import apply for foldl/4, map_list_to_pairs/3.
:- use_module(library(pairs)).   % Import pairs for keysort/2, pairs_values/2.
:- use_module(library(random)).  % Import random for random_permutation/2.
:- use_module(library(assoc)).   % Import assoc for empty_assoc/1, put_assoc/4, get_assoc/3.

% Simple greedy construction:
% Assign each lecture to the first available (day,period,room) that does not
% violate teacher/room/curriculum/unavailability. Good enough for tiny fixtures.

% construct(+Instance, -Solution)
% Top-level entry: build slot and room lists, pre-compute lookup maps,
% order tasks by difficulty, then try up to 30 randomised placement attempts.
construct(Instance, Solution) :-
    Days is Instance.days,                    % Extract the total number of days from the instance.
    Periods is Instance.periods_per_day,      % Extract periods per day from the instance.
    MaxD is Days - 1,                         % Compute the maximum day index (0-based).
    MaxP is Periods - 1,                      % Compute the maximum period index (0-based).
    findall(slot(D,P), (between(0, MaxD, D), between(0, MaxP, P)), Slots0), % Generate all (D,P) slot terms.
    random_permutation(Slots0, Slots),        % Shuffle slots to diversify initial placement order.
    Instance.rooms = Rooms0,                  % Extract the room list from the instance dict.
    random_permutation(Rooms0, Rooms),        % Shuffle rooms for randomised room assignment.
    build_teacher_map(Instance.courses, TeacherMap),          % Build course→teacher assoc map.
    build_course_curricula_map(Instance.curricula, CurrMap),  % Build course→curricula-set assoc map.
    build_tasks(Instance, CurrMap, Tasks),    % Generate and sort tasks (one per lecture, most-constrained first).
    try_attempts(30, Instance, Rooms, Slots, TeacherMap, CurrMap, Tasks, Solution). % Try up to 30 restarts.

% try_attempts(+N, +Instance, +Rooms, +Slots, +TeacherMap, +CurrMap, +Tasks, -Solution)
% Attempt to schedule all tasks up to N times with different random orderings.
try_attempts(0, _Instance, _Rooms, _Slots, _TeacherMap, _CurrMap, _Tasks, _Solution) :-
    !,    % No more attempts left; cut to prevent backtracking into this clause.
    fail. % All 30 attempts exhausted without finding a feasible schedule; fail.
try_attempts(AttemptsLeft, Instance, Rooms0, Slots0, TeacherMap, CurrMap, Tasks0, Solution) :-
    random_permutation(Rooms0, Rooms),        % Re-shuffle rooms for this attempt.
    random_permutation(Slots0, Slots),        % Re-shuffle slots for this attempt.
    random_permutation(Tasks0, Tasks),        % Re-shuffle tasks to vary ordering within most-constrained priority.
    (   schedule_tasks(Tasks, Instance, Rooms, Slots, TeacherMap, CurrMap, [], Solution) % Try scheduling.
    ->  !                                     % Success: cut to keep this solution and stop retrying.
    ;   Attempts1 is AttemptsLeft - 1,        % Scheduling failed; decrement attempt counter.
        try_attempts(Attempts1, Instance, Rooms0, Slots0, TeacherMap, CurrMap, Tasks0, Solution) % Recurse.
    ).

% Build tasks = one per lecture, with a simple difficulty ordering.
% Each task is task(Course, LectureIndex).
% build_tasks(+Instance, +CurrMap, -TasksSorted)
% Generate one task/2 per lecture (across all courses) and sort descending by difficulty weight.
build_tasks(Instance, CurrMap, TasksSorted) :-
    findall(task(Course, I),                  % Collect all task/2 terms.
        ( member(course(Course, _T, Lectures, _MD, _S), Instance.courses), % Each course.
          Lectures > 0,                       % Skip courses with zero lectures.
          MaxI is Lectures - 1,              % Compute max lecture index.
          between(0, MaxI, I)                % Generate each lecture index 0..MaxI.
        ),
        Tasks),
    map_list_to_pairs(task_weight(Instance, CurrMap), Tasks, Pairs), % Pair each task with its weight.
    keysort(Pairs, SortedPairsAsc),           % Sort ascending by weight.
    reverse(SortedPairsAsc, SortedPairsDesc), % Reverse to get descending order (most-constrained first).
    pairs_values(SortedPairsDesc, TasksSorted). % Extract the task values, discarding weights.

% task_weight(+Instance, +CurrMap, +task(Course,_), -W)
% Compute difficulty weight for a task: sum of unavailability count and curriculum membership count.
% Higher weight = schedule earlier (most-constrained first).
task_weight(Instance, CurrMap, task(Course, _I), W) :-
    % Higher weight = schedule earlier.
    findall(1, member(unavailable(Course, _D, _P), Instance.unavailability), Unav), % Count unavailable slots.
    length(Unav, UnavCount),                  % UnavCount = number of forbidden slots for this course.
    ( get_assoc(Course, CurrMap, Currs) -> length(Currs, CurrCount) ; CurrCount = 0 ), % Curriculum memberships.
    W is UnavCount + CurrCount.               % Weight = unavailability + curriculum membership count.

% schedule_tasks(+Tasks, +Instance, +Rooms, +Slots, +TeacherMap, +CurrMap, +Acc, -Solution)
% Recursively place each task in the greedy order; accumulate assignments in Acc.
schedule_tasks([], _Instance, _Rooms, _Slots, _TeacherMap, _CurrMap, Sol, Sol). % Base: all tasks placed; Sol done.
schedule_tasks([task(Course, LectureIndex)|Rest], Instance, Rooms, Slots, TeacherMap, CurrMap, Acc, Solution) :-
    place_greedy(Course, LectureIndex, Instance, Rooms, Slots, TeacherMap, CurrMap, Acc, Acc1), % Place this task.
    schedule_tasks(Rest, Instance, Rooms, Slots, TeacherMap, CurrMap, Acc1, Solution). % Continue with rest.

% place_greedy(+Course, +LectureIndex, +Instance, +Rooms, +Slots,
%              +TeacherMap, +CurrMap, +Acc, -NewAcc)
% Find the first (slot, room) combination that passes all hard checks and add it to Acc.
place_greedy(Course, LectureIndex, Instance, Rooms, Slots, TeacherMap, CurrMap, Acc,
             [assignment(Course, LectureIndex, Day, Period, RoomId)|Acc]) :-
    member(slot(Day, Period), Slots),         % Try each slot in the permuted order.
    member(room(RoomId, _Cap), Rooms),        % Try each room in the permuted order.
    can_place(Course, Day, Period, RoomId, Instance, TeacherMap, CurrMap, Acc), % Check all hard constraints.
    !. % Cut: accept the first feasible (slot, room) found; do not backtrack into more options.

% can_place(+Course, +Day, +Period, +RoomId, +Instance, +TeacherMap, +CurrMap, +Acc)
% True when placing Course at (Day,Period,RoomId) does not violate any hard constraint,
% given the partial solution Acc already built.
can_place(Course, Day, Period, RoomId, Instance, TeacherMap, CurrMap, Acc) :-
    % Unavailability
    \+ memberchk(unavailable(Course, Day, Period), Instance.unavailability), % H6: slot not forbidden.
    % Same course not twice in same slot
    \+ memberchk(assignment(Course, _I, Day, Period, _R), Acc),  % H3: course not already at this slot.
    % Room conflict
    \+ memberchk(assignment(_OC, _OI, Day, Period, RoomId), Acc), % H2: room not already occupied this slot.
    % Teacher conflict
    ( get_assoc(Course, TeacherMap, Teacher) -> true ; Teacher = '' ), % Look up teacher; default '' if none.
    \+ ( member(assignment(OtherCourse, _OJ, Day, Period, _OR), Acc), % H4: no other course by same teacher.
         OtherCourse \= Course,              % Ignore self-conflicts (already handled above).
         get_assoc(OtherCourse, TeacherMap, Teacher) % Other course has same teacher.
       ),
    % Curriculum conflict
    ( get_assoc(Course, CurrMap, CourseCurrs) -> true ; CourseCurrs = [] ), % Look up curricula for Course.
    \+ ( member(assignment(OtherCourse, _OK, Day, Period, _RR), Acc), % H5: no curriculum overlap.
         OtherCourse \= Course,              % Only check other courses.
         get_assoc(OtherCourse, CurrMap, OtherCurrs), % Look up curricula for the other course.
         intersects(CourseCurrs, OtherCurrs) % Conflict if the two courses share a curriculum.
       ).

% intersects(+List1, +List2)
% True when List1 and List2 have at least one common element.
intersects([X|_], Ys) :- memberchk(X, Ys), !. % Found X in Ys: lists intersect; cut to avoid further search.
intersects([_|Xs], Ys) :- intersects(Xs, Ys).  % X not in Ys; try remaining elements of List1.

% build_teacher_map(+Courses, -Assoc)
% Build an association list mapping each course ID to its teacher ID.
build_teacher_map(Courses, Assoc) :-
    empty_assoc(A0),                      % Start with an empty assoc (balanced tree).
    foldl(put_teacher, Courses, A0, Assoc). % Fold put_teacher over all courses to build the map.

% put_teacher(+course(...), +A0, -A)
% Insert a single course→teacher mapping into the assoc.
put_teacher(course(Course, Teacher, _L, _MD, _S), A0, A) :-
    put_assoc(Course, A0, Teacher, A).    % Add Course→Teacher entry to the assoc.

% build_course_curricula_map(+Curricula, -Assoc)
% Build an association list mapping each course ID to the list of curricula it belongs to.
build_course_curricula_map(Curricula, Assoc) :-
    empty_assoc(A0),                       % Start with an empty assoc.
    foldl(put_curriculum, Curricula, A0, Assoc). % Fold put_curriculum over all curricula.

% put_curriculum(+curriculum(CurrId,Courses), +A0, -A)
% For each course in the curriculum, add CurrId to that course's curriculum list in the assoc.
put_curriculum(curriculum(CurrId, Courses), A0, A) :-
    foldl(add_course_to_curr(CurrId), Courses, A0, A). % Apply add_course_to_curr for each course.

% add_course_to_curr(+CurrId, +Course, +A0, -A)
% Append CurrId to the curriculum list for Course in the assoc, avoiding duplicates.
add_course_to_curr(CurrId, Course, A0, A) :-
    (   get_assoc(Course, A0, Currs0)      % Check if Course already has a curriculum list.
    ->  ( memberchk(CurrId, Currs0) -> Currs = Currs0 ; Currs = [CurrId|Currs0] ), % Avoid duplicate entries.
        put_assoc(Course, A0, Currs, A)    % Update the assoc with the (possibly extended) list.
    ;   put_assoc(Course, A0, [CurrId], A) % Course not yet in assoc: initialise with single-element list.
    ).
