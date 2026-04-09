:- module(soft_constraints, [penalty/3]). % Declare 'soft_constraints' module; export penalty/3.

:- use_module(library(lists)). % Import lists library for member/2 and sum_list/2.

% Soft constraints (Track 2 - Curriculum-based Course Timetabling):
% - Room capacity (weight: 1)     — students exceed room capacity
% - Minimum working days (weight: 5) — course not spread across enough days
% - Curriculum compactness (weight: 2) — isolated lectures in a curriculum
% - Room stability (weight: 1)    — course spread across multiple rooms

% penalty(+Instance, +Solution, -TotalPenalty)
% Compute the sum of all four soft-constraint penalty components for Solution.
penalty(Instance, Solution, TotalPenalty) :-
    room_capacity_penalty(Instance, Solution, RoomCapPenalty),   % Compute S1: room capacity penalty.
    min_working_days_penalty(Instance, Solution, MinDaysPenalty),% Compute S2: minimum working days penalty.
    curriculum_compactness_penalty(Instance, Solution, CompactPenalty),  % Compute S3: compactness penalty.
    room_stability_penalty(Instance, Solution, StabilityPenalty), % Compute S4: room stability penalty.
    TotalPenalty is RoomCapPenalty + MinDaysPenalty + CompactPenalty + StabilityPenalty. % Sum all components.

% -----------------------------------------------------------------------------
% Room Capacity: For each lecture, students > room capacity contributes 1 per student
% Weight: 1
% -----------------------------------------------------------------------------
% room_capacity_penalty(+Instance, +Solution, -Penalty)
% For every assignment whose course has more students than the room's capacity,
% add (Students - Capacity) to the penalty. Weight is 1 per excess student.
room_capacity_penalty(Instance, Solution, Penalty) :-
    findall(P, (                               % Collect a list P of positive penalties.
        member(assignment(Course, _LectureIdx, _Day, _Period, RoomId), Solution), % Each assignment.
        member(course(Course, _Teacher, _Lectures, _MinDays, Students), Instance.courses), % Get students count.
        member(room(RoomId, Capacity), Instance.rooms), % Get room capacity.
        Students > Capacity,                   % Only count when students exceed capacity.
        P is Students - Capacity               % Penalty = excess students (weight 1 per student).
    ), Violations),
    sum_list(Violations, Penalty).             % Sum all individual penalties into total room capacity penalty.

% -----------------------------------------------------------------------------
% Minimum Working Days: lectures should be spread over minDays days
% Weight: 5 per day below minimum
% -----------------------------------------------------------------------------
% min_working_days_penalty(+Instance, +Solution, -Penalty)
% For each course that is scheduled on fewer days than its MinDays requirement,
% add 5 × (MinDays - ActualDays) to the penalty.
min_working_days_penalty(Instance, Solution, Penalty) :-
    findall(P, (                               % Collect penalties for each under-spread course.
        member(course(Course, _Teacher, _Lectures, MinDays, _Students), Instance.courses), % Each course.
        MinDays > 0,                           % Only consider courses with a positive minimum day requirement.
        findall(Day, member(assignment(Course, _I, Day, _Period, _R), Solution), Days0), % Collect used days.
        sort(Days0, Days),                     % Remove duplicate days to count distinct days used.
        length(Days, ActualDays),              % Count the number of distinct days actually used.
        ActualDays < MinDays,                  % Violation: not enough distinct days.
        P is (MinDays - ActualDays) * 5        % Penalty = 5 per missing day.
    ), Violations),
    sum_list(Violations, Penalty).             % Sum all individual penalties into total min-days penalty.

% -----------------------------------------------------------------------------
% Curriculum Compactness: lectures in same curriculum should be adjacent
% Weight: 2 per isolated lecture
% An isolated lecture is one not adjacent to any other lecture in the same day
% -----------------------------------------------------------------------------
% curriculum_compactness_penalty(+Instance, +Solution, -Penalty)
% For each curriculum, count lectures that have no adjacent lecture (same day, period ±1)
% in the same curriculum. Each such isolated lecture costs 2.
curriculum_compactness_penalty(Instance, Solution, Penalty) :-
    findall(P, (                               % Collect compactness penalties per curriculum.
        member(curriculum(_CurriculumId, Courses), Instance.curricula), % Each curriculum.
        curriculum_isolated_count(Courses, Solution, NumIsolated),      % Count isolated lectures.
        NumIsolated > 0,                       % Only accumulate when at least one isolation exists.
        P is NumIsolated * 2                   % Penalty = 2 per isolated lecture.
    ), Violations),
    sum_list(Violations, Penalty).             % Sum all curriculum compactness penalties.

% curriculum_isolated_count(+Courses, +Solution, -NumIsolated)
% Count the number of (day, period) lecture slots for courses in Courses
% that have no adjacent lecture (period ±1 same day) from the same curriculum.
curriculum_isolated_count(Courses, Solution, NumIsolated) :-
    findall(d(D)-p(P), (               % Collect all (day, period) slots used by courses in this curriculum.
        member(Course, Courses),       % Iterate over each course in the curriculum.
        member(assignment(Course, _L, D, P, _R), Solution) % Find each assignment of the course.
    ), AllDPs),
    sort(AllDPs, SortedDPs),           % Sort and deduplicate to get unique (day,period) pairs.
    count_isolated(SortedDPs, 0, NumIsolated). % Count how many of those slots are isolated.

% count_isolated(+SortedDPs, +Acc, -Total)
% Walk the sorted list of d(D)-p(P) terms and count entries with no adjacent entry.
count_isolated([], Acc, Acc).           % Base case: no more slots; Total = accumulated count.
count_isolated([d(D)-p(P)|Rest], Acc, Total) :- % Recursive case: examine the slot at day D, period P.
    ( member(d(D)-p(P1), Rest),         % Search the remaining sorted list for the same day D.
      (P1 is P + 1 ; P1 is P - 1)      % Check if P1 is the period immediately before or after P.
    ->  count_isolated(Rest, Acc, Total) % Found an adjacent slot: not isolated; continue without incrementing.
    ;   NewAcc is Acc + 1,             % No adjacent slot found: this slot is isolated; increment counter.
        count_isolated(Rest, NewAcc, Total) % Recurse with updated accumulator.
    ).

% -----------------------------------------------------------------------------
% Room Stability: all lectures of a course should be in the same room
% Weight: 1 per extra room used
% -----------------------------------------------------------------------------
% room_stability_penalty(+Instance, +Solution, -Penalty)
% For each course that uses more than one distinct room across its lectures,
% add (NumRooms - 1) to the penalty (weight 1 per extra room).
room_stability_penalty(Instance, Solution, Penalty) :-
    findall(P, (                               % Collect stability penalties per course.
        member(course(Course, _Teacher, Lectures, _MinDays, _Students), Instance.courses), % Each course.
        Lectures > 0,                          % Only consider courses that have lectures to place.
        findall(RoomId, member(assignment(Course, _I, _D, _P, RoomId), Solution), Rooms0), % Collect room IDs.
        sort(Rooms0, Rooms),                   % Deduplicate to get distinct rooms used.
        length(Rooms, NumRooms),               % Count distinct rooms.
        NumRooms > 1,                          % Violation: more than one room used for this course.
        P is NumRooms - 1                      % Penalty = number of extra rooms (weight 1 each).
    ), Violations),
    sum_list(Violations, Penalty).             % Sum all room stability penalties.
