# `command jw` does the work and prints where to go; a function is needed to cd there.
function jw --description 'jj workspaces at <repo>.agents/<name>'
    switch "$argv[1]"
        case new n cd c rm clone
            set -l dir (command jw $argv)
            or return
            if test (count $dir) -eq 1 -a -d "$dir"
                cd $dir
            else if test -n "$dir"
                printf '%s\n' $dir
            end
        case '*'
            command jw $argv
    end
end
