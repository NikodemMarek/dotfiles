#!/bin/sh

for url in "$@"
do
  youtube-dl -f "bestaudio/best" -ciw -o "$HOME/.config/beets/.tmp/%(title)s.%(ext)s" -v --extract-audio --audio-format flac --audio-quality 0 --yes-playlist "$url"

  printf '\nA' | beet import -w -a -g -m "./.tmp"
done
