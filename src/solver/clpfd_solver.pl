:- module(clpfd_solver, [construct/2]). % Declare module; export construct/2 as the solver entry point.

:- use_module(library(clpfd)).  % Import CLP(FD) library for finite-domain constraint variables.
:- use_module(library(lists)).  % Import lists library for member/2 and memberchk/2.

% Simple CLPFD model for learners:
% - one slot variable per lecture
% - one room variable per lecture
% - pairwise hard constraints between lectures

% construct(+Instance, -Solution)
% Top-level predicate: post CLP(FD) constraints, label, then decode assignments.
construct(Instance, Solution) :-
    build_lectures(Instance.courses, Lectures),   % Collect one lecture/2 term per required lecture event.
    length(Lectures, N),                          % N = total number of lecture events to schedule.
    length(SlotVars, N),                          % Create N unbound slot variables (one per lecture).
    length(RoomVars, N),                          % Create N unbound room variables (one per lecture).
    NumSlots is Instance.days * Instance.periods_per_day, % Total slots = days × periods/day.
    length(Instance.rooms, NumRooms),             % NumRooms = number of rooms in the instance.
    NumSlots > 0,                                 % Guard: instance must have at least one time slot.
    NumRooms > 0,                                 % Guard: instance must have at least one room.
    MaxSlot is NumSlots - 1,                      % Slots are 0-indexed; compute upper bound.
    SlotVars ins 0..MaxSlot,                      % Domain for slot variables: [0, MaxSlot].
    RoomVars ins 1..NumRooms,                     % Domain for room variables: [1, NumRooms] (1-indexed).
    constrain_unavailability(Lectures, SlotVars, Instance.unavailability,
        Instance.periods_per_day),                % Post unavailability constraints for each lecture.
    constrain_pairs(Lectures, SlotVars, RoomVars, Instance.curricula), % Post pairwise hard constraints.
    append(SlotVars, RoomVars, Vars),             % Combine slot and room vars for labeling.
    labeling([ffc], Vars),                        % Label variables using first-fail principle (ffc).
    build_solution(Lectures, SlotVars, RoomVars, Instance.rooms,
        Instance.periods_per_day, Solution).      % Decode labeled variables into assignment/5 terms.

% build_lectures(+Courses, -Lectures)
% Enumerate every individual lecture event across all courses.
build_lectures(Courses, Lectures) :-
    findall(lecture(Course, LectureIndex, Teacher),  % Collect lecture/3 terms.
        ( member(course(Course, Teacher, LectureCount, _MinDays, _Students), Courses), % For each course,
          LectureCount > 0,                          % skip courses with zero required lectures,
          MaxIndex is LectureCount - 1,              % compute 0-indexed upper bound for lectures,
          between(0, MaxIndex, LectureIndex)         % generate one index per lecture.
        ),
        Lectures).                                   % Lectures = flat list of all lecture events.

% constrain_unavailability(+Lectures, +SlotVars, +Unavailability, +PeriodsPerDay)
% Base case: no more lectures to process.
constrain_unavailability([], [], _Unavailability, _PeriodsPerDay).
% Recursive case: post unavailability constraints for the head lecture, then recurse.
constrain_unavailability([lecture(Course, _LectureIndex, _Teacher)|Lectures],
        [Slot|Slots], Unavailability, PeriodsPerDay) :-
    constrain_course_unavailability(Course, Slot, Unavailability, PeriodsPerDay), % Post for this lecture.
    constrain_unavailability(Lectures, Slots, Unavailability, PeriodsPerDay).     % Recurse on the rest.

% constrain_course_unavailability(+Course, +Slot, +Unavailability, +PeriodsPerDay)
% Base case: unavailability list exhausted; no more constraints to post.
constrain_course_unavailability(_Course, _Slot, [], _PeriodsPerDay).
% Recursive case: if this constraint belongs to Course, forbid the corresponding slot.
constrain_course_unavailability(Course, Slot,
        [unavailable(UnavailableCourse, Day, Period)|Rest], PeriodsPerDay) :-
    (   Course == UnavailableCourse               % Check whether this unavailability applies to Course.
    ->  ForbiddenSlot is Day * PeriodsPerDay + Period, % Convert (Day, Period) to flat slot index.
        Slot #\= ForbiddenSlot                    % CLP(FD) inequality: Slot must not be the forbidden one.
    ;   true                                      % Different course; skip silently.
    ),
    constrain_course_unavailability(Course, Slot, Rest, PeriodsPerDay). % Recurse on remaining constraints.

% constrain_pairs(+Lectures, +SlotVars, +RoomVars, +Curricula)
% Base case: no lectures remain; done.
constrain_pairs([], [], [], _Curricula).
% Recursive case: post constraints between the head lecture and all subsequent lectures, then recurse.
constrain_pairs([Lecture|Lectures], [Slot|Slots], [Room|Rooms], Curricula) :-
    constrain_with_rest(Lecture, Slot, Room, Lectures, Slots, Rooms, Curricula), % Head vs rest.
    constrain_pairs(Lectures, Slots, Rooms, Curricula).                          % Recurse on tail.

% constrain_with_rest(+Lecture, +Slot, +Room, +RestLectures, +RestSlots, +RestRooms, +Curricula)
% Base case: no remaining lectures to pair with.
constrain_with_rest(_Lecture, _Slot, _Room, [], [], [], _Curricula).
% Recursive case: post pairwise constraints between Lecture1 and Lecture2.
constrain_with_rest(lecture(Course1, LectureIndex1, Teacher1), Slot1, Room1,
        [lecture(Course2, _LectureIndex2, Teacher2)|Lectures], [Slot2|Slots],
        [Room2|Rooms], Curricula) :-
    % Same course: two lectures cannot be in the same slot.
    (   Course1 == Course2                        % Both events belong to the same course.
    ->  Slot1 #\= Slot2                           % Hard constraint: distinct slots for the same course.
    ;   true                                      % Different courses; no same-course constraint.
    ),
    % Same teacher: courses taught by the same teacher cannot overlap.
    (   Course1 \== Course2,                      % Exclude same-course pairs already handled above.
        Teacher1 == Teacher2                      % Both courses share a teacher.
    ->  Slot1 #\= Slot2                           % Hard constraint: teacher cannot teach two at once.
    ;   true                                      % Different teachers; skip.
    ),
    % Same curriculum: courses in one curriculum cannot overlap.
    (   Course1 \== Course2,                      % Exclude same-course pairs.
        share_curriculum(Course1, Course2, Curricula) % Both courses belong to a common curriculum.
    ->  Slot1 #\= Slot2                           % Hard constraint: curriculum courses cannot clash.
    ;   true                                      % No shared curriculum; skip.
    ),
    % Room conflict: same room cannot host two lectures in one slot.
    (Slot1 #\= Slot2) #\/ (Room1 #\= Room2),     % At least one of slot or room must differ.
    constrain_with_rest(lecture(Course1, LectureIndex1, Teacher1), Slot1, Room1,
        Lectures, Slots, Rooms, Curricula).       % Continue pairing Lecture1 with remaining lectures.

% share_curriculum(+Course1, +Course2, +Curricula)
% Succeeds if Course1 and Course2 both appear in the same curriculum group.
share_curriculum(Course1, Course2, Curricula) :-
    member(curriculum(_CurriculumId, Courses), Curricula), % Pick any curriculum.
    memberchk(Course1, Courses),                           % Course1 must be in it.
    memberchk(Course2, Courses),                           % Course2 must also be in it.
    !.                                                     % Cut: one shared curriculum is sufficient.

% build_solution(+Lectures, +SlotVars, +RoomVars, +Rooms, +PeriodsPerDay, -Solution)
% Base case: no lectures left; solution is empty.
build_solution([], [], [], _Rooms, _PeriodsPerDay, []).
% Recursive case: decode the labeled slot and room values for the head lecture.
build_solution([lecture(Course, LectureIndex, _Teacher)|Lectures], [Slot|Slots],
        [RoomVar|RoomVars], Rooms, PeriodsPerDay,
        [assignment(Course, LectureIndex, Day, Period, RoomId)|Solution]) :-
    Day is Slot // PeriodsPerDay,                % Integer division gives the day index.
    Period is Slot mod PeriodsPerDay,            % Modulo gives the period within the day.
    nth1(RoomVar, Rooms, room(RoomId, _Capacity)), % 1-indexed lookup: map RoomVar to room ID.
    build_solution(Lectures, Slots, RoomVars, Rooms, PeriodsPerDay, Solution). % Recurse on the rest.
