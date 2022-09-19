#!/bin/sh

: ${XSECURELOCK_IMAGE_PATH:=$HOME/pictures/wallpapers/neon-city.png}
feh --auto-zoom --window-id="${XSCREENSAVER_WINDOW}" -F "${XSECURELOCK_IMAGE_PATH}"
