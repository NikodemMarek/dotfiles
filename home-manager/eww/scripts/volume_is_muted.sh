pactl subscribe | while read -r _
do
  # pactl get-sink-mute 4 | awk '{print $2 ~ /yes/}'
  amixer get Master | grep 'Right:' | awk '{print $6 == "[on]"}'
done
