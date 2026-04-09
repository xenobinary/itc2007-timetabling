:- module(hard_constraints, [  % Declare the 'hard_constraints' module, exporting:
    feasible/2,               %   feasible/2  — true iff a solution violates no hard constraint.
    violates/3,               %   violates/3  — true iff a complete solution has at least one violation.
    violates_partial/3        %   violates_partial/3 — same but for partial solutions (skips completeness).
]).

:- use_module(library(lists)). % Import lists library for member/2 used throughout constraint checking.

% Core hard constraints for ITC2007 Track 2 (simplified):
% - all lectures scheduled        (H1: completeness)
% - no room conflicts             (H2: room uniqueness per slot)
% - no teacher conflicts          (H4: teacher uniqueness per slot)
% - no curriculum conflicts       (H5: curriculum uniqueness per slot)
% - no unavailability violations  (H6: forbidden slots respected)

% feasible(+Instance, +Solution)
% True when Solution contains no violations for any of the six hard constraints.
feasible(Instance, Solution) :-
    \+ violates(Instance, Solution, _). % Succeed iff there exists no constraint violation term.

% violates(+Instance, +Solution, -Reason)
% True (semidet) when Solution violates at least one hard constraint.
% Reason is a descriptive term for the first violation found.
violates(Instance, Solution, Reason) :-
    ( violates_lecture_count(Instance, Solution, Reason)  % Check H1: all required lectures are present.
    ; violates_partial(Instance, Solution, Reason)        % Check H2-H6: structural hard constraints.
    ),
    !. % Cut: stop after finding the first violation; we only need to detect one.

% Partial violations used while constructing a timetable.
% Omits lecture-count completeness because the solution is still being built.
% violates_partial(+Instance, +Solution, -Reason)
% True when Solution violates any structural constraint (H2–H6), ignoring H1.
violates_partial(Instance, Solution, Reason) :-
    ( violates_room_conflict(Solution, Reason)                % Check H2: no two courses in same room/slot.
    ; violates_course_conflict(Solution, Reason)              % Check H3: a course not scheduled twice in same slot.
    ; violates_teacher_conflict(Instance, Solution, Reason)   % Check H4: teacher not teaching two courses at once.
    ; violates_curriculum_conflict(Instance, Solution, Reason)% Check H5: no curriculum overlap in same slot.
    ; violates_unavailability(Instance, Solution, Reason)     % Check H6: no assignment in forbidden slots.
    ),
    !. % Cut: stop after the first violation found.

% violates_lecture_count(+Instance, +Solution, -missing_lecture(Course))
% True when some course in Instance does not have exactly the required number of
% distinct lecture-index assignments in Solution.
violates_lecture_count(Instance, Solution, missing_lecture(Course)) :-
    member(course(Course, _Teacher, Lectures, _MinDays, _Students), Instance.courses), % Iterate over courses.
    findall(I, member(assignment(Course, I, _D, _P, _R), Solution), Is), % Collect all lecture indices assigned.
    sort(Is, Unique),      % Remove duplicates (sort also deduplicates) to count distinct lecture indices.
    length(Unique, N),     % Count the number of distinct lecture indices found in Solution.
    N =\= Lectures.        % Fail if the count matches; succeed (violation) if count differs from required.

% violates_room_conflict(+Solution, -room_conflict(Day,Period,Room))
% True when two distinct courses are both assigned to the same Room at the same (Day,Period).
violates_room_conflict(Solution, room_conflict(Day,Period,Room)) :-
    member(assignment(C1, _I1, Day, Period, Room), Solution), % Pick a first assignment with (Day,Period,Room).
    member(assignment(C2, _I2, Day, Period, Room), Solution), % Pick a second assignment at the same slot/room.
    C1 \= C2.                                                  % Violation: the two courses are different.

% violates_course_conflict(+Solution, -course_conflict(Course,Day,Period))
% True when the same Course has two distinct lecture indices in the same (Day,Period) slot.
violates_course_conflict(Solution, course_conflict(Course,Day,Period)) :-
    member(assignment(Course, I1, Day, Period, _R1), Solution), % Pick one lecture of Course at (Day,Period).
    member(assignment(Course, I2, Day, Period, _R2), Solution), % Pick another assignment of Course at same slot.
    I1 \= I2.                                                    % Violation: two distinct lecture indices in one slot.

% violates_teacher_conflict(+Instance, +Solution, -teacher_conflict(Teacher,Day,Period))
% True when the same Teacher is assigned to two different courses in the same (Day,Period).
violates_teacher_conflict(Instance, Solution, teacher_conflict(Teacher,Day,Period)) :-
    course_teacher(Instance, C1, Teacher),   % Look up one course C1 taught by Teacher.
    course_teacher(Instance, C2, Teacher),   % Look up another course C2 taught by the same Teacher.
    C1 \= C2,                                % Violation only when the two courses are different.
    member(assignment(C1, _I1, Day, Period, _R1), Solution), % C1 is scheduled at (Day,Period).
    member(assignment(C2, _I2, Day, Period, _R2), Solution). % C2 is also scheduled at the same (Day,Period).

% violates_curriculum_conflict(+Instance, +Solution, -curriculum_conflict(Curr,Day,Period))
% True when two courses that share curriculum Curr are both scheduled at the same (Day,Period).
violates_curriculum_conflict(Instance, Solution, curriculum_conflict(Curr,Day,Period)) :-
    member(curriculum(Curr, Courses), Instance.curricula), % Iterate over all curricula.
    member(C1, Courses),                                   % Pick a first course from the curriculum.
    member(C2, Courses),                                   % Pick a second course from the same curriculum.
    C1 \= C2,                                              % Violation requires two distinct courses.
    member(assignment(C1, _I1, Day, Period, _R1), Solution), % C1 is scheduled at (Day,Period).
    member(assignment(C2, _I2, Day, Period, _R2), Solution). % C2 is also scheduled at (Day,Period) — conflict.

% violates_unavailability(+Instance, +Solution, -unavailability(Course,Day,Period))
% True when a Course is assigned to a (Day,Period) that is declared unavailable for it.
violates_unavailability(Instance, Solution, unavailability(Course,Day,Period)) :-
    member(unavailable(Course,Day,Period), Instance.unavailability), % Find a declared unavailable slot.
    member(assignment(Course, _I, Day, Period, _R), Solution).       % Course is actually scheduled there — violation.

% course_teacher(+Instance, ?Course, ?Teacher)
% Helper: look up the Teacher of Course in the instance's courses list.
course_teacher(Instance, Course, Teacher) :-
    member(course(Course, Teacher, _L, _MD, _S), Instance.courses). % Unify via member/2 search.
