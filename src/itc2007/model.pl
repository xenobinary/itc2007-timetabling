:- module(model, [       % Declare the 'model' module, exporting the following predicates:
    empty_instance/1,   %   empty_instance/1 — create a blank instance dict.
    add_course/3,       %   add_course/3 — prepend a course term to the instance.
    add_room/3,         %   add_room/3 — prepend a room term to the instance.
    add_curriculum/3,   %   add_curriculum/3 — prepend a curriculum term to the instance.
    add_unavailability/5 %  add_unavailability/5 — prepend an unavailability term.
]).

% Instance is a SWI-Prolog dict with the following keys:
%   name            — string identifier from the .ctt header (e.g. "TESTBED")
%   days            — integer number of scheduling days
%   periods_per_day — integer number of periods per day
%   courses_count   — integer count of courses (from header, used to take exact lines)
%   rooms_count     — integer count of rooms (from header)
%   curricula_count — integer count of curricula (from header)
%   constraints_count — integer count of unavailability constraints (from header)
%   courses         — list of course/5 terms: course(Id,Teacher,Lectures,MinDays,Students)
%   rooms           — list of room/2 terms: room(Id,Capacity)
%   curricula       — list of curriculum/2 terms: curriculum(Id,[CourseIds])
%   unavailability  — list of unavailable/3 terms: unavailable(Course,Day,Period)

empty_instance(I) :-           % Construct an empty instance dict with all fields at their zero/default values.
    I = instance{             % Use the SWI-Prolog dict literal syntax with tag 'instance'.
        name:'',              % Initially no name; the parser fills this from the Name: header line.
        days:0,               % Initially zero days; overwritten by Days: header field.
        periods_per_day:0,    % Initially zero periods; overwritten by Periods_per_day: header field.
        courses_count:0,      % Initially zero; overwritten by Courses: header field.
        rooms_count:0,        % Initially zero; overwritten by Rooms: header field.
        curricula_count:0,    % Initially zero; overwritten by Curricula: header field.
        constraints_count:0,  % Initially zero; overwritten by Constraints: header field.
        courses:[],           % Empty list of course/5 terms — appended as the parser reads COURSES section.
        rooms:[],             % Empty list of room/2 terms — appended as the parser reads ROOMS section.
        curricula:[],         % Empty list of curriculum/2 terms — appended from CURRICULA section.
        unavailability:[]     % Empty list of unavailable/3 terms — appended from UNAVAILABILITY_CONSTRAINTS.
    }.

add_course(I0, Course, I) :-              % Prepend Course to the courses list in instance dict I0, giving I.
    I = I0.put(courses, [Course|I0.courses]). % Use dict .put/2 to update the 'courses' key.

add_room(I0, Room, I) :-                  % Prepend Room to the rooms list in instance dict I0, giving I.
    I = I0.put(rooms, [Room|I0.rooms]).   % Use dict .put/2 to update the 'rooms' key.

add_curriculum(I0, Curriculum, I) :-               % Prepend Curriculum to the curricula list in I0, giving I.
    I = I0.put(curricula, [Curriculum|I0.curricula]). % Use dict .put/2 to update 'curricula'.

add_unavailability(I0, Course, Day, Period, I) :-  % Prepend an unavailable/3 term for Course at (Day,Period).
    I = I0.put(unavailability,                     % Use dict .put/2 to update 'unavailability'.
        [unavailable(Course,Day,Period)|I0.unavailability]). % Cons new term onto the existing list.
