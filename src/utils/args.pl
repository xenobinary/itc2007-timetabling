:- module(args, [parse_args/2, print_help/0]).

% Minimal argv parsing to keep the project dependency-free.
% Supported:
%   --instance <path>
%   --out <path>
%   --csv <path>
%   --seed <int>
%   --timelimit <seconds>
%   --help

parse_args(Argv, Opts) :-
    default_opts(Default),
    parse_kv(Argv, Default, Opts).

default_opts(opts{instance:'', out:'', csv:'', seed:0, timelimit:30, help:false}).

parse_kv([], Opts, Opts) :-
    require(Opts).
parse_kv(['--help'|Rest], Opts0, Opts) :-
    Opts1 = Opts0.put(help, true),
    parse_kv(Rest, Opts1, Opts).
parse_kv(['--instance',Path|Rest], Opts0, Opts) :-
    Opts1 = Opts0.put(instance, Path),
    parse_kv(Rest, Opts1, Opts).
parse_kv(['--out',Path|Rest], Opts0, Opts) :-
    Opts1 = Opts0.put(out, Path),
    parse_kv(Rest, Opts1, Opts).
parse_kv(['--csv',Path|Rest], Opts0, Opts) :-
    Opts1 = Opts0.put(csv, Path),
    parse_kv(Rest, Opts1, Opts).
parse_kv(['--seed',S|Rest], Opts0, Opts) :-
    atom_number(S, N),
    Opts1 = Opts0.put(seed, N),
    parse_kv(Rest, Opts1, Opts).
parse_kv(['--timelimit',S|Rest], Opts0, Opts) :-
    atom_number(S, N),
    Opts1 = Opts0.put(timelimit, N),
    parse_kv(Rest, Opts1, Opts).
parse_kv([Unknown|_], _, _) :-
    format(user_error, 'Unknown arg: ~w~n', [Unknown]),
    print_help,
    halt(2).

require(Opts) :-
    (Opts.help == true -> true ;
        ( Opts.instance == '' -> format(user_error, 'Missing --instance~n', []), print_help, halt(2) ; true ),
        ( Opts.out == '' -> format(user_error, 'Missing --out~n', []), print_help, halt(2) ; true )
    ).

print_help :-
    format('Usage: swipl -q -g "[src/main], main([...])" -t halt~n', []),
    format('Options:~n', []),
    format('  --instance <file.ctt>   ITC2007 Track2 instance~n', []),
    format('  --out <file.sol>        Output solution file~n', []),
    format('  --csv <file.csv>        Write stats (feasible,penalty)~n', []),
    format('  --seed <int>            RNG seed (optional)~n', []),
    format('  --timelimit <sec>       Time limit (optional)~n', []).
