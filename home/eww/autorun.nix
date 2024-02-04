{ lib, ... }:
let
  windows = [
    "powermenu"
    "system"
    "time"
    "music"
    "shortcuts"
    "volume"
    "app_list"
  ];
in
''
  eww daemon

  ${lib.concatStrings ( builtins.map ( win: ''
    eww open ${win}
  '') windows )}
''
