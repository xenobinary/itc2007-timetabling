:- module(model, [
    empty_instance/1,
    add_course/3,
    add_room/3,
    add_curriculum/3,
    add_unavailability/5
]).

% Instance is a dict with keys:
% name, days, periods_per_day, courses, rooms, curricula, unavailability

empty_instance(I) :-
    I = instance{
        name:'',
        days:0,
        periods_per_day:0,
        courses_count:0,
        rooms_count:0,
        curricula_count:0,
        constraints_count:0,
        courses:[],          % list(course(Id,Teacher,Lectures,MinDays,Students))
        rooms:[],            % list(room(Id,Capacity))
        curricula:[],        % list(curriculum(Id,Courses))
        unavailability:[]    % list(unavailable(Course,Day,Period))
    }.

add_course(I0, Course, I) :-
    I = I0.put(courses, [Course|I0.courses]).

add_room(I0, Room, I) :-
    I = I0.put(rooms, [Room|I0.rooms]).

add_curriculum(I0, Curriculum, I) :-
    I = I0.put(curricula, [Curriculum|I0.curricula]).

add_unavailability(I0, Course, Day, Period, I) :-
    I = I0.put(unavailability, [unavailable(Course,Day,Period)|I0.unavailability]).
