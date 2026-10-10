function __jw_repos  # a glob matching nothing is an error in a command (only `set` is exempt)
    set -l d ~/projects/*/.jj
    path dirname $d | path basename
end

complete -c jw -f
complete -c jw -n __fish_use_subcommand -a 'new n cd c rm clone prune info ls'
complete -c jw -n '__fish_seen_subcommand_from new n' -s r -l revision -r -d 'revision to start from (default: trunk())'
complete -c jw -n '__fish_seen_subcommand_from new n' -a '(__jw_repos)'
complete -c jw -n '__fish_seen_subcommand_from cd c' -a '(jj --ignore-working-copy workspace list -T \'name ++ "\n"\' 2>/dev/null | string match -v default)'
complete -c jw -n '__fish_seen_subcommand_from rm' -a '(jj --ignore-working-copy workspace list -T \'name ++ "\n"\' 2>/dev/null | string match -v default)'
