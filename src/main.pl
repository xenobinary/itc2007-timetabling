:- module(main, [main/1]).

:- use_module(src/utils/args).
:- use_module(src/itc2007/parser).
:- use_module(src/solver/solver).
:- use_module(src/output/writer).
:- use_module(src/output/validator).
:- use_module(library(random)).

main(Argv) :-
    args:parse_args(Argv, Opts),
    (   get_dict(help, Opts, true)
    ->  args:print_help,
        halt(0)
    ;   true
    ),
    InstancePath = Opts.instance,
    OutPath = Opts.out,
    CsvPath = Opts.csv,
    Seed = Opts.seed,
    ( Seed =:= 0 -> set_random(seed(1)) ; set_random(seed(Seed)) ),
    parser:read_instance(InstancePath, Instance),
    solver:solve(Instance, Opts, Solution, Stats),
    writer:write_solution(OutPath, Solution),
    (   validator:check_hard_constraints(Instance, Solution)
    ->  true
    ;   format(user_error, 'WARNING: produced solution violates hard constraints~n', [])
    ),
    (   CsvPath \= ''
    ->  writer:write_csv(CsvPath, Stats)
    ;   true
    ),
    (   Stats.feasible == true
    ->  halt(0)
    ;   halt(2)
    ).
