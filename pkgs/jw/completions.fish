complete -c jw -f
complete -c jw -n __fish_use_subcommand -a 'new cd rm ls'
complete -c jw -n '__fish_seen_subcommand_from new' -s r -l revision -r -d 'revision to start from (default: trunk())'
complete -c jw -n '__fish_seen_subcommand_from cd rm' -a '(jj --ignore-working-copy workspace list -T \'name ++ "\n"\' 2>/dev/null | string match -v default)'
