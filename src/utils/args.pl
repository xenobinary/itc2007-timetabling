:- module(args, [parse_args/2, print_help/0]). % Declare module; export parse_args/2 and print_help/0.

% Minimal argv parsing to keep the project dependency-free.
% Supported:
%   --instance <path>
%   --out <path>
%   --csv <path>
%   --solver <constructive|clpfd>
%   --seed <int>
%   --timelimit <seconds>
%   --help

% parse_args(+Argv, -Opts)
% Parse a list of command-line tokens into an options dict.
parse_args(Argv, Opts) :-
    default_opts(Default),       % Start from the default options dict.
    parse_kv(Argv, Default, Opts). % Recursively consume tokens, accumulating options.

% default_opts(-Opts)
% Produce the baseline options dict with all fields set to their defaults.
default_opts(opts{instance:'', out:'', csv:'', solver:constructive, seed:0,
    timelimit:30, help:false}).  % Defaults: no instance/output paths, constructive solver, 30 s.

% parse_kv(+Argv, +Opts0, -Opts)
% Base case: no tokens left; validate required fields.
parse_kv([], Opts, Opts) :-
    require(Opts).               % After all tokens consumed, ensure mandatory fields are set.
% --help flag: set help:true and continue.
parse_kv(['--help'|Rest], Opts0, Opts) :-
    Opts1 = Opts0.put(help, true), % Record that --help was requested.
    parse_kv(Rest, Opts1, Opts).   % Continue parsing remaining tokens.
% --instance <path>: set the instance file path.
parse_kv(['--instance',Path|Rest], Opts0, Opts) :-
    Opts1 = Opts0.put(instance, Path), % Store the instance path.
    parse_kv(Rest, Opts1, Opts).       % Continue parsing.
% --out <path>: set the output solution file path.
parse_kv(['--out',Path|Rest], Opts0, Opts) :-
    Opts1 = Opts0.put(out, Path),  % Store the output path.
    parse_kv(Rest, Opts1, Opts).   % Continue parsing.
% --csv <path>: set the optional CSV stats output path.
parse_kv(['--csv',Path|Rest], Opts0, Opts) :-
    Opts1 = Opts0.put(csv, Path),  % Store the CSV path.
    parse_kv(Rest, Opts1, Opts).   % Continue parsing.
% --solver <name>: set the solver strategy (constructive or clpfd).
parse_kv(['--solver',Solver0|Rest], Opts0, Opts) :-
    normalize_solver(Solver0, Solver),           % Normalize atom/string to atom.
    (   memberchk(Solver, [constructive, clpfd]) % Validate solver name.
    ->  Opts1 = Opts0.put(solver, Solver),       % Valid: store the solver choice.
        parse_kv(Rest, Opts1, Opts)              % Continue parsing.
    ;   format(user_error, 'Unknown solver: ~w~n', [Solver0]), % Invalid: report error.
        print_help,                              % Show usage information.
        halt(2)                                  % Exit with error code 2.
    ).
% --seed <int>: set the RNG seed for reproducibility.
parse_kv(['--seed',S|Rest], Opts0, Opts) :-
    atom_number(S, N),             % Convert the string/atom token to a number.
    Opts1 = Opts0.put(seed, N),    % Store the seed value.
    parse_kv(Rest, Opts1, Opts).   % Continue parsing.
% --timelimit <sec>: set the solver time limit in seconds.
parse_kv(['--timelimit',S|Rest], Opts0, Opts) :-
    atom_number(S, N),             % Convert the string/atom token to a number.
    Opts1 = Opts0.put(timelimit, N), % Store the time limit value.
    parse_kv(Rest, Opts1, Opts).   % Continue parsing.
% Unknown flag: report error, print help, and exit.
parse_kv([Unknown|_], _, _) :-
    format(user_error, 'Unknown arg: ~w~n', [Unknown]), % Report the unknown argument.
    print_help,                    % Show usage information.
    halt(2).                       % Exit with error code 2.

% require(+Opts)
% Validate that mandatory options (--instance and --out) are present unless --help was given.
require(Opts) :-
    (Opts.help == true -> true ;   % If --help was requested, skip mandatory-field checks.
        ( Opts.instance == '' -> format(user_error, 'Missing --instance~n', []), print_help, halt(2) ; true ), % Require instance.
        ( Opts.out == '' -> format(user_error, 'Missing --out~n', []), print_help, halt(2) ; true ) % Require output path.
    ).

% normalize_solver(+Solver0, -Solver)
% Coerce the solver name to an atom regardless of whether it arrived as atom or string.
normalize_solver(Solver0, Solver) :-
    (   atom(Solver0)             % Already an atom.
    ->  Solver = Solver0          % Keep it as-is.
    ;   string(Solver0)           % Arrived as a SWI-Prolog string.
    ->  atom_string(Solver, Solver0) % Convert to atom.
    ;   Solver = Solver0          % Fallback: pass through unchanged.
    ).

% print_help/0
% Print usage information to stdout.
print_help :-
    format('Usage: swipl -q -g "[src/main], main([...])" -t halt~n', []), % Show invocation template.
    format('Options:~n', []),                                              % Header for option list.
    format('  --instance <file.ctt>   ITC2007 Track2 instance~n', []),    % Describe --instance.
    format('  --out <file.sol>        Output solution file~n', []),        % Describe --out.
    format('  --csv <file.csv>        Write stats (feasible,penalty)~n', []), % Describe --csv.
    format('  --solver <name>         constructive | clpfd~n', []),        % Describe --solver.
    format('  --seed <int>            RNG seed (optional)~n', []),         % Describe --seed.
    format('  --timelimit <sec>       Time limit (optional)~n', []).       % Describe --timelimit.
