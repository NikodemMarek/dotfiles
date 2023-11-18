{ lib, ... }:
let
  windows = [
    "powermenu"
    "system"
    "time"
    "music"
    "launcher"
  ];
in
''
  eww daemon

  ${lib.concatStrings ( builtins.map ( win: ''
    eww open ${win}
  '') windows )}
''
