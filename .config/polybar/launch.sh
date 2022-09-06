#!/usr/bin/env bash

# Terminate already running bar instances
polybar-msg cmd quit

# Launch main bar
echo "---" | tee -a /tmp/polybar1.log /tmp/polybar2.log
polybar main 2>&1 | tee -a /tmp/polybar1.log & disown

echo "Bars launched..."
