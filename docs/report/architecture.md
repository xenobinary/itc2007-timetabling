# Architecture Notes

## Components
- Parser: reads `.ctt` into a normalized instance dict
- Knowledge base: hard/soft constraints as Prolog rules
- Solver: construction + improvement
- Validator: checks feasibility
- Writer: produces ITC2007-compatible `.sol`

## Key representations
- `instance{...}` dict
- `assignment(Course, LectureIndex, Day, Period, Room)` terms
