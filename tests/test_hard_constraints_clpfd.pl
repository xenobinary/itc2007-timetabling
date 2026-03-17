:- begin_tests(hard_constraints_clpfd).

:- use_module('../src/itc2007/parser').
:- use_module('../src/rules/hard_constraints_clpfd').

% ---- helpers -----------------------------------------------------------

mini_instance(I) :-
    once(parser:read_instance('tests/fixtures/mini.ctt', I)).

% Valid solution for the mini fixture.
% The parser returns course/room IDs as strings, so use double-quoted atoms.
%   C1 lecture 0 -> Day 0, Period 1, Room R1  (Day 0 Period 0 is unavailable for C1)
%   C2 lecture 0 -> Day 1, Period 0, Room R2  (different day avoids CURR1 conflict)
valid_solution([
    assignment("C1", 0, 0, 1, "R1"),
    assignment("C2", 0, 1, 0, "R2")
]).

% ---- feasibility -------------------------------------------------------

test(feasible_valid_solution) :-
    mini_instance(I),
    valid_solution(Sol),
    hard_constraints_clpfd:feasible_clpfd(I, Sol).

test(infeasible_empty_solution) :-
    mini_instance(I),
    \+ hard_constraints_clpfd:feasible_clpfd(I, []).

% ---- lecture count -----------------------------------------------------

test(violates_missing_lecture) :-
    mini_instance(I),
    % Empty solution: C1 has 1 required lecture but 0 assigned
    hard_constraints_clpfd:violates_clpfd(I, [], missing_lecture("C1")).

test(no_lecture_count_violation_when_complete) :-
    mini_instance(I),
    valid_solution(Sol),
    \+ hard_constraints_clpfd:violates_clpfd(I, Sol, missing_lecture(_)).

% ---- room conflict -----------------------------------------------------

test(violates_room_conflict) :-
    mini_instance(I),
    % Two courses in the same room at the same time
    Sol = [assignment("C1", 0, 1, 0, "R1"),
           assignment("C2", 0, 1, 0, "R1")],
    hard_constraints_clpfd:violates_clpfd(I, Sol, room_conflict(1, 0, "R1")).

test(no_room_conflict_different_rooms) :-
    mini_instance(I),
    valid_solution(Sol),
    \+ hard_constraints_clpfd:violates_clpfd(I, Sol, room_conflict(_, _, _)).

% ---- course conflict ---------------------------------------------------

test(violates_course_conflict) :-
    mini_instance(I),
    % C1 lecture 0 and lecture 1 assigned to the same slot
    Sol = [assignment("C1", 0, 1, 0, "R1"),
           assignment("C1", 1, 1, 0, "R2")],
    hard_constraints_clpfd:violates_clpfd(I, Sol, course_conflict("C1", 1, 0)).

% ---- teacher conflict --------------------------------------------------

test(no_teacher_conflict_different_teachers) :-
    mini_instance(I),
    valid_solution(Sol),
    \+ hard_constraints_clpfd:violates_clpfd(I, Sol, teacher_conflict(_, _, _)).

% ---- curriculum conflict -----------------------------------------------

test(violates_curriculum_conflict) :-
    mini_instance(I),
    % C1 and C2 are both in CURR1; same slot is a conflict
    Sol = [assignment("C1", 0, 1, 0, "R1"),
           assignment("C2", 0, 1, 0, "R2")],
    hard_constraints_clpfd:violates_clpfd(I, Sol, curriculum_conflict("CURR1", 1, 0)).

test(no_curriculum_conflict_different_slots) :-
    mini_instance(I),
    valid_solution(Sol),
    \+ hard_constraints_clpfd:violates_clpfd(I, Sol, curriculum_conflict(_, _, _)).

% ---- unavailability ----------------------------------------------------

test(violates_unavailability) :-
    mini_instance(I),
    % C1 is unavailable at Day 0 Period 0 in the mini fixture
    Sol = [assignment("C1", 0, 0, 0, "R1"),
           assignment("C2", 0, 1, 0, "R2")],
    hard_constraints_clpfd:violates_clpfd(I, Sol, unavailability("C1", 0, 0)).

test(no_unavailability_violation) :-
    mini_instance(I),
    valid_solution(Sol),
    \+ hard_constraints_clpfd:violates_clpfd(I, Sol, unavailability(_, _, _)).

:- end_tests(hard_constraints_clpfd).
