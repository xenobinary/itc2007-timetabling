:- begin_tests(hard_constraints_clpfd). % Open the 'hard_constraints_clpfd' plunit test suite.

:- use_module('../src/itc2007/parser').              % Load parser to read the mini fixture.
:- use_module('../src/rules/hard_constraints_clpfd'). % Load the CLP(FD)-style hard constraints module under test.

% ---- helpers -----------------------------------------------------------

% mini_instance(-I)
% Helper: parse the mini fixture once and bind I to the resulting instance dict.
mini_instance(I) :-
    once(parser:read_instance('tests/fixtures/mini.ctt', I)). % Parse the mini fixture; keep first solution.

% Valid solution for the mini fixture.
% The parser returns course/room IDs as strings, so use double-quoted atoms.
%   C1 lecture 0 -> Day 0, Period 1, Room R1  (Day 0 Period 0 is unavailable for C1)
%   C2 lecture 0 -> Day 1, Period 0, Room R2  (different day avoids CURR1 conflict)
% valid_solution(-Sol)
% Helper: provide a hard-constraint-satisfying assignment list for the mini fixture.
valid_solution([
    assignment("C1", 0, 0, 1, "R1"), % C1 lecture 0 placed at Day 0 Period 1 in Room R1.
    assignment("C2", 0, 1, 0, "R2")  % C2 lecture 0 placed at Day 1 Period 0 in Room R2.
]).

% ---- feasibility -------------------------------------------------------

% test: feasible_valid_solution
% The known-good assignment must pass the full feasibility check.
test(feasible_valid_solution) :-
    mini_instance(I),              % Load the mini instance.
    valid_solution(Sol),           % Retrieve the valid solution.
    hard_constraints_clpfd:feasible_clpfd(I, Sol). % Assert no hard constraints are violated.

% test: infeasible_empty_solution
% An empty assignment list must fail feasibility (lectures are not all scheduled).
test(infeasible_empty_solution) :-
    mini_instance(I),                               % Load the mini instance.
    \+ hard_constraints_clpfd:feasible_clpfd(I, []). % An empty solution cannot be feasible.

% ---- lecture count -----------------------------------------------------

% test: violates_missing_lecture
% An empty solution should produce a missing_lecture violation for C1.
test(violates_missing_lecture) :-
    mini_instance(I),                        % Load the mini instance.
    % Empty solution: C1 has 1 required lecture but 0 assigned
    hard_constraints_clpfd:violates_clpfd(I, [], missing_lecture("C1")). % Expect missing_lecture("C1").

% test: no_lecture_count_violation_when_complete
% A complete solution must not trigger any missing_lecture violations.
test(no_lecture_count_violation_when_complete) :-
    mini_instance(I),                                                          % Load the mini instance.
    valid_solution(Sol),                                                       % Retrieve the valid solution.
    \+ hard_constraints_clpfd:violates_clpfd(I, Sol, missing_lecture(_)).     % No missing lectures allowed.

% ---- room conflict -----------------------------------------------------

% test: violates_room_conflict
% Two courses assigned to the same room at the same time must produce a room_conflict violation.
test(violates_room_conflict) :-
    mini_instance(I),                    % Load the mini instance.
    % Two courses in the same room at the same time
    Sol = [assignment("C1", 0, 1, 0, "R1"), % C1 at Day 1 Period 0 Room R1.
           assignment("C2", 0, 1, 0, "R1")], % C2 at Day 1 Period 0 Room R1 — same slot and room.
    hard_constraints_clpfd:violates_clpfd(I, Sol, room_conflict(1, 0, "R1")). % Expect room_conflict.

% test: no_room_conflict_different_rooms
% The valid solution places courses in different rooms, so no room conflict should occur.
test(no_room_conflict_different_rooms) :-
    mini_instance(I),                                                        % Load the mini instance.
    valid_solution(Sol),                                                     % Retrieve the valid solution.
    \+ hard_constraints_clpfd:violates_clpfd(I, Sol, room_conflict(_, _, _)). % No room conflicts allowed.

% ---- course conflict ---------------------------------------------------

% test: violates_course_conflict
% Two lectures of the same course in the same slot must produce a course_conflict violation.
test(violates_course_conflict) :-
    mini_instance(I),                    % Load the mini instance.
    % C1 lecture 0 and lecture 1 assigned to the same slot
    Sol = [assignment("C1", 0, 1, 0, "R1"), % C1 lecture 0 at Day 1 Period 0 Room R1.
           assignment("C1", 1, 1, 0, "R2")], % C1 lecture 1 at Day 1 Period 0 Room R2 — same slot.
    hard_constraints_clpfd:violates_clpfd(I, Sol, course_conflict("C1", 1, 0)). % Expect course_conflict.

% ---- teacher conflict --------------------------------------------------

% test: no_teacher_conflict_different_teachers
% The valid solution has courses taught by different teachers, so no teacher conflict should occur.
test(no_teacher_conflict_different_teachers) :-
    mini_instance(I),                                                            % Load the mini instance.
    valid_solution(Sol),                                                         % Retrieve the valid solution.
    \+ hard_constraints_clpfd:violates_clpfd(I, Sol, teacher_conflict(_, _, _)). % No teacher conflicts allowed.

% ---- curriculum conflict -----------------------------------------------

% test: violates_curriculum_conflict
% Two courses sharing a curriculum scheduled in the same slot must produce a curriculum_conflict.
test(violates_curriculum_conflict) :-
    mini_instance(I),                    % Load the mini instance.
    % C1 and C2 are both in CURR1; same slot is a conflict
    Sol = [assignment("C1", 0, 1, 0, "R1"), % C1 at Day 1 Period 0 Room R1.
           assignment("C2", 0, 1, 0, "R2")], % C2 at Day 1 Period 0 Room R2 — same slot, different room.
    hard_constraints_clpfd:violates_clpfd(I, Sol, curriculum_conflict("CURR1", 1, 0)). % Expect curriculum_conflict.

% test: no_curriculum_conflict_different_slots
% The valid solution places C1 and C2 in different slots, so no curriculum conflict should occur.
test(no_curriculum_conflict_different_slots) :-
    mini_instance(I),                                                                   % Load the mini instance.
    valid_solution(Sol),                                                                % Retrieve the valid solution.
    \+ hard_constraints_clpfd:violates_clpfd(I, Sol, curriculum_conflict(_, _, _)).    % No curriculum conflicts allowed.

% ---- unavailability ----------------------------------------------------

% test: violates_unavailability
% Scheduling C1 at its declared unavailable slot must produce an unavailability violation.
test(violates_unavailability) :-
    mini_instance(I),                    % Load the mini instance.
    % C1 is unavailable at Day 0 Period 0 in the mini fixture
    Sol = [assignment("C1", 0, 0, 0, "R1"), % C1 at Day 0 Period 0 — the forbidden slot.
           assignment("C2", 0, 1, 0, "R2")], % C2 at Day 1 Period 0 — valid.
    hard_constraints_clpfd:violates_clpfd(I, Sol, unavailability("C1", 0, 0)). % Expect unavailability violation.

% test: no_unavailability_violation
% The valid solution avoids all declared unavailable slots.
test(no_unavailability_violation) :-
    mini_instance(I),                                                               % Load the mini instance.
    valid_solution(Sol),                                                            % Retrieve the valid solution.
    \+ hard_constraints_clpfd:violates_clpfd(I, Sol, unavailability(_, _, _)).     % No unavailability violations allowed.

:- end_tests(hard_constraints_clpfd). % Close the 'hard_constraints_clpfd' test suite.
