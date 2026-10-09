# `command jw` does the work and prints where to go; a function is needed to cd there.
function jw --description 'jj workspaces at <repo>.agents/<name>'
    switch "$argv[1]"
        case new cd rm
            set -l dir (command jw $argv)
            or return
            if test -n "$dir"
                cd $dir
            end
        case '*'
            command jw $argv
    end
end
