# AGENTS.md - Agentic Coding Guidelines

This is a **SWI-Prolog** project implementing an expert system for ITC2007 Course Timetabling.

## Build / Run Commands

### Run the Solver
```bash
make run                           # Using Makefile (default instance)
make run INSTANCE=data/itc2007/comp01.ctt OUT=results/comp01.sol  # Custom instance
swipl -q -g "[src/main], main(['--instance','data/itc2007/comp01.ctt','--out','results/comp01.sol'])" -t halt
```

### Run Tests
```bash
make test                          # Run all tests
swipl -q -g "[tests/test_runner]" -t halt
```

### Run a Single Test
```bash
swipl -q -g "[tests/test_parser], run_tests([parser])" -t halt
swipl -q -g "[tests/test_parser], test(read_mini_instance_has_name_and_counts)" -t halt
```

### Validate a Solution
```bash
make validate INSTANCE=data/itc2007/comp01.ctt SOL=results/comp01.sol
```

### Command-Line Options
| Flag | Description | Required |
|------|-------------|----------|
| `--instance <path>` | ITC2007 Track2 instance file (.ctt) | Yes |
| `--out <path>` | Output solution file (.sol) | Yes |
| `--csv <path>` | Write stats (feasible, penalty) | No |
| `--seed <int>` | RNG seed (0 = default seed) | No |
| `--timelimit <sec>` | Time limit in seconds (default: 30) | No |

### Exit Codes
- `0`: Success (feasible solution found)
- `1`: Error
- `2`: Infeasible solution (violates hard constraints)

---

## Code Style Guidelines

### Module Declaration
```prolog
:- module(module_name, [exported_predicate/arity, another_predicate/2]).
```
Use singular names for modules (e.g., `parser.pl` → `parser`).

### Imports
```prolog
:- use_module(library(readutil)).
:- use_module(src/itc2007/model).
```

### Naming Conventions
- **Files/Modules**: snake_case (e.g., `test_parser.pl`)
- **Predicates**: snake_case (e.g., `read_instance/2`)
- **Variables**: Capitalized snake_case (e.g., `InstancePath`)
- **Atoms**: lowercase (e.g., `'COURSES:'`)
- **Dict Keys**: camelCase (e.g., `name`, `periodsPerDay`)

### Data Structures

**Dicts** for complex objects:
```prolog
empty_instance(I) :- I = instance{name:'', days:0, courses:[]}.
I.courses, get_dict(courses, I, C), I1 = I0.put(courses, [New|I0.courses]).
```

**Terms** for domain entities:
```prolog
course(CourseId, TeacherId, Lectures, MinDays, Students)
room(RoomId, Capacity)
```

### Code Layout
- Max line length: 80-100 characters
- Use 4 spaces for indentation
- Section comments: `% -------------------------`

### Error Handling
```prolog
format(user_error, 'Error: ~w~n', [Msg]), fail.
catch(number_string(N, S), _, fail).
```

### Testing (plunit)
```prolog
:- begin_tests(module_name).
:- use_module(src/itc2007/parser).

test(test_name) :-
    once(parser:read_instance('tests/fixtures/mini.ctt', I)),
    assertion(I.name \= ''), assertion(I.days =:= 2).
:- end_tests(module_name).
```
- Test files: `tests/test_<module>.pl`
- Use `once/1` to avoid choice points

### Best Practices
1. Always specify arity in exports and calls
2. Use mode declarations: `%! read_instance(+atom, -dict)`
3. Prefer pure predicates (avoid cut/0)
4. Close streams with `setup_call_cleanup/3`
5. Avoid global state - pass state as arguments

---

## Project Structure
```
src/
├── main.pl, validate.pl
├── itc2007/   (model.pl, parser.pl)
├── rules/     (hard_constraints.pl, soft_constraints.pl)
├── solver/    (solver.pl, constructive.pl, local_search.pl)
├── output/    (writer.pl, validator.pl)
└── utils/     (args.pl)
tests/
├── test_runner.pl, test_parser.pl, test_constructive.pl
└── fixtures/
```

### Adding a New Module
1. Create `src/<subdir>/<module>.pl`
2. Declare module with `:- module(...).`
3. Export predicates

### Running Benchmarks
```bash
./scripts/benchmark.sh
```
