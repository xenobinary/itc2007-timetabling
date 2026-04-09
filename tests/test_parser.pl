:- begin_tests(parser). % Open the 'parser' plunit test suite.

:- use_module('../src/itc2007/parser'). % Load the parser module under test.

% test: read_mini_instance_has_name_and_counts
% Verify that the mini fixture is parsed into a well-formed instance dict.
test(read_mini_instance_has_name_and_counts) :-
    once(parser:read_instance('tests/fixtures/mini.ctt', I)), % Parse the mini fixture; keep first solution.
    I.name \= '',           % The instance name must be non-empty.
    I.days =:= 2,           % The fixture defines 2 days.
    I.periods_per_day =:= 2, % The fixture defines 2 periods per day.
    I.courses_count =:= 2,  % The fixture declares 2 courses.
    I.rooms_count =:= 2,    % The fixture declares 2 rooms.
    I.courses = [_|_],      % The courses list must be non-empty (at least one element).
    I.rooms = [_|_].        % The rooms list must be non-empty (at least one element).

:- end_tests(parser). % Close the 'parser' test suite.
