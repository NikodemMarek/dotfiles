# `jw`: the python script does the work; the fish function cds where it says.
# fzf is pinned; jj comes from the user's PATH.
{
  runCommand,
  python3,
  fzf,
}:
runCommand "jw" {} ''
  install -Dm755 ${./jw.py} $out/bin/jw
  substituteInPlace $out/bin/jw \
    --replace-fail "#!/usr/bin/env python3" "#!${python3}/bin/python3" \
    --replace-fail 'FZF = "fzf"' 'FZF = "${fzf}/bin/fzf"'
  install -Dm644 ${./jw.fish} $out/share/fish/vendor_functions.d/jw.fish
  install -Dm644 ${./completions.fish} $out/share/fish/vendor_completions.d/jw.fish
''
