#!/bin/sh
getdefaultsinkname() {
  pacmd stat | awk -F": " '/^Default sink name: /{print $2}'
}

getdefaultsinkvol() {
  amixer get Master | grep 'Right:' | awk -F'[][]' '{print substr($2, 1, length($2)-1)}'
  # pacmd list-sinks | awk '/^\s+name: /{indefault = $2 == "<'$(getdefaultsinkname)'>"}/^\s+volume: / && indefault {print $5; exit}' | tr -d %
}

pactl subscribe | while read -r _
do
  getdefaultsinkvol
done
