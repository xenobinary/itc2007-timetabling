:- module(main, [main/1]). % Declare the 'main' module, exporting the single entry-point predicate main/1.

:- use_module(utils/args).    % Import the args module for CLI argument parsing.
:- use_module(itc2007/parser). % Import the parser module for reading .ctt instance files.
:- use_module(solver/solver).  % Import the solver dispatcher that selects constructive or CLP(FD).
:- use_module(output/writer).  % Import the writer module for solution and CSV output.
:- use_module(library(random)). % Import SWI-Prolog's random library for seeding the RNG.

main(Argv) :-                         % Entry point: Argv is the list of command-line atom arguments.
    args:parse_args(Argv, Opts),      % Parse Argv into an options dict Opts (instance, out, solver, seed, ...).
    (   get_dict(help, Opts, true)    % Check if the --help flag was set in Opts.
    ->  args:print_help,              % If help was requested, print usage information to stdout.
        halt(0)                       % Exit with code 0 (success) after printing help.
    ;   true                          % Otherwise, do nothing and continue.
    ),
    InstancePath = Opts.instance,     % Extract the instance file path from the options dict.
    OutPath = Opts.out,               % Extract the output solution file path from the options dict.
    CsvPath = Opts.csv,               % Extract the optional CSV stats file path (empty string if not given).
    Seed = Opts.seed,                 % Extract the random seed (0 means use default seed 1).
    ( Seed =:= 0 -> set_random(seed(1)) ; set_random(seed(Seed)) ), % Initialise the RNG: seed 0 maps to 1.
    parser:read_instance(InstancePath, Instance),   % Parse the .ctt file into the instance dict.
    solver:solve(Instance, Opts, Solution, Stats),  % Run the selected solver; returns Solution and Stats.
    writer:write_solution(OutPath, Solution),        % Write the assignment list to the .sol output file.
    (   CsvPath \= ''                               % Check whether a CSV path was provided (non-empty).
    ->  writer:write_csv(CsvPath, Stats)            % If yes, write feasibility and penalty to the CSV file.
    ;   true                                        % Otherwise, skip CSV output.
    ),
    (   Stats.feasible == true        % Check whether the solver found a feasible solution.
    ->  halt(0)                       % Feasible: exit with code 0 to signal success.
    ;   halt(2)                       % Infeasible: exit with code 2 to signal a constraint violation.
    ).
