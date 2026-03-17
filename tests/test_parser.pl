:- begin_tests(parser).

:- use_module('../src/itc2007/parser').

test(read_mini_instance_has_name_and_counts) :-
    once(parser:read_instance('tests/fixtures/mini.ctt', I)),
    I.name \= '',
    I.days =:= 2,
    I.periods_per_day =:= 2,
    I.courses_count =:= 2,
    I.rooms_count =:= 2,
    I.courses = [_|_],
    I.rooms = [_|_].

:- end_tests(parser).
