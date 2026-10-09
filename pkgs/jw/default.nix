# `jw`: the python script does the work; the fish function cds where it says.
# jj comes from the user's PATH.
{
  runCommand,
  python3,
}:
runCommand "jw" {} ''
  install -Dm755 ${./jw.py} $out/bin/jw
  substituteInPlace $out/bin/jw --replace-fail "#!/usr/bin/env python3" "#!${python3}/bin/python3"
  install -Dm644 ${./jw.fish} $out/share/fish/vendor_functions.d/jw.fish
  install -Dm644 ${./completions.fish} $out/share/fish/vendor_completions.d/jw.fish
''
