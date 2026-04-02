# AGENTS.md - Agentic Coding Guidelines

This is a **SWI-Prolog** project implementing an expert system for ITC2007 Course Timetabling.

## Build / Run Commands

### Run the Solver
```bash
make run                           # Constructive solver (default)
make run INSTANCE=data/itc2007/comp01.ctt OUT=results/comp01.sol TIMEOUT=120
make run-clpfd INSTANCE=data/itc2007/comp01.ctt OUT=results/comp01-clpfd.sol TIMEOUT=120
make run-all-constructive INST_DIR=data/itc2007 OUT_DIR=results/constructive-batch TIMEOUT=120
make run-all-clpfd INST_DIR=data/itc2007 OUT_DIR=results/clpfd-batch TIMEOUT=120
```

### Run Tests
```bash
make test                          # Run all tests via test_runner
swipl -q -g "[tests/test_runner]" -t halt
```

### Run a Single Test Suite or Individual Test
```bash
# Run an entire test suite
swipl -q -g "[tests/test_parser], run_tests([parser])" -t halt

# Run a single named test
swipl -q -g "[tests/test_parser], test(read_mini_instance_has_name_and_counts)" -t halt
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
:- use_module(itc2007/model).          % relative to src/
:- use_module('../rules/hard_constraints').  % cross-subdir: use relative path
```
- Library modules: `library(name)`
- Project modules: relative path from the file's directory (no `.pl` extension)

### Naming Conventions
- **Files/Modules**: snake_case (e.g., `test_parser.pl`)
- **Predicates**: snake_case (e.g., `read_instance/2`)
- **Variables**: CapitalizedCamelCase or Capitalized_snake_case (e.g., `InstancePath`)
- **Atoms**: lowercase (e.g., `'COURSES:'`)
- **Dict Keys**: camelCase (e.g., `name`, `periodsPerDay`)

### Data Structures

**Dicts** for complex objects (instance, stats, options):
```prolog
empty_instance(I) :- I = instance{name:'', days:0, courses:[]}.
I1 = I0.put(courses, [New|I0.courses]).
get_dict(courses, I, C).
```

**Compound terms** for domain entities:
```prolog
course(CourseId, TeacherId, Lectures, MinDays, Students)
room(RoomId, Capacity)
curriculum(CurriculumId, Courses)
assignment(Course, LectureIdx, Day, Period, RoomId)
```

### Code Layout
- Max line length: 80-100 characters
- Use 4 spaces for indentation
- Section headers: `% --- Section Name ---` or `% -------------------------`
- Place `:- use_module/2` directives after `:- module/2`

### Error Handling
```prolog
format(user_error, 'Error: ~w~n', [Msg]), fail.
catch(number_string(N, S), _, fail).
```
- Use `format(user_error, ...)` for error messages
- Use `setup_call_cleanup/3` for resource management (streams, files)

### Testing (plunit)
```prolog
:- begin_tests(parser).
:- use_module('../src/itc2007/parser').

test(read_mini_instance_has_name_and_counts) :-
    once(parser:read_instance('tests/fixtures/mini.ctt', I)),
    I.name \= '',
    I.days =:= 2.
:- end_tests(parser).
```
- Test files: `tests/test_<module>.pl`
- Test runner: `tests/test_runner.pl` uses `:- initialization(run_tests, main).`
- Use `once/1` to avoid choice points in tests
- Run individual tests: `test(test_name)` goal
- Run suites: `run_tests([suite_name])` goal

### Best Practices
1. Always specify arity in exports and calls
2. Prefer pure predicates (avoid cut/0); use cuts only for deterministic dispatch
3. Close streams with `setup_call_cleanup/3`
4. Avoid global state - pass state as arguments
5. Use `module:goal` syntax for cross-module calls in tests
6. Use `ensure_loaded/1` in test_runner; use `use_module/2` elsewhere

---

## Project Structure
```
src/
├── main.pl                          # Entry point, CLI dispatch
├── itc2007/
│   ├── model.pl                     # Instance data structures (dicts + terms)
│   └── parser.pl                    # ITC2007 .ctt file parser
├── rules/
│   ├── hard_constraints.pl          # Feasibility checks (conflicts, coverage)
│   └── soft_constraints.pl          # Penalty calculation (4 soft constraints)
├── solver/
│   ├── solver.pl                    # Dispatch (constructive vs clpfd)
│   ├── constructive.pl              # Greedy randomized construction
│   └── clpfd_solver.pl              # CLP(FD) constraint solver
├── output/
│   └── writer.pl                    # Solution file + CSV output
└── utils/
    └── args.pl                      # CLI argument parsing
tests/
├── test_runner.pl                   # Aggregates all test suites
├── test_parser.pl
├── test_constructive.pl
├── test_clpfd_solver.pl
└── fixtures/                        # Small test instances (.ctt)
```

### Adding a New Module
1. Create `src/<subdir>/<module>.pl`
2. Declare module: `:- module(module_name, [exported/arity]).`
3. Export only public predicates; keep helpers internal
4. Add `:- use_module(...)` imports for dependencies
5. Create corresponding `tests/test_<module>.pl` with plunit tests
6. Register new test suite in `tests/test_runner.pl`
