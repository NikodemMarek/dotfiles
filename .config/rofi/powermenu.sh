#!/usr/bin/env bash

# Inspired by
# Aditya Shakya (adi1090x)

# Options
shutdown=''
reboot='累'
lock=''
logout=''
suspend=''
hibernate=''

# Rofi CMD
rofi_cmd() {
	rofi -dmenu -theme ./powermenu.rasi
}

# Pass variables to rofi dmenu
run_rofi() {
	echo -e "$lock\n$suspend\n$hibernate\n$shutdown\n$reboot\n$logout" | rofi_cmd
}

# Execute Command
run_cmd() {
	if [[ $1 == '--shutdown' ]]; then
		systemctl poweroff
	elif [[ $1 == '--reboot' ]]; then
		systemctl reboot
	elif [[ $1 == '--lock' ]]; then
		env XSECURELOCK_SAVER=$HOME/.config/xsecurelock/lock.sh env XSECURELOCK_DISCARD_FIRST_KEYPRESS=0 env XSECURELOCK_SHOW_HOSTNAME=0 xsecurelock
	elif [[ $1 == '--logout' ]]; then
		bspc quit
	elif [[ $1 == '--suspend' ]]; then
		systemctl suspend
	elif [[ $1 == '--hibernate' ]]; then
		systemctl hibernate
	else
		exit 0
	fi

  if [[ $2 == '--lock' ]]; then
		env XSECURELOCK_SAVER=$HOME/.config/xsecurelock/lock.sh env XSECURELOCK_DISCARD_FIRST_KEYPRESS=0 env XSECURELOCK_SHOW_HOSTNAME=0 xsecurelock
  fi
}

# Actions
chosen="$(run_rofi)"
case ${chosen} in
    $shutdown)
		run_cmd --shutdown
        ;;
    $reboot)
		run_cmd --reboot
        ;;
    $lock)
		run_cmd --lock
        ;;
    $logout)
		run_cmd --logout
        ;;
    $suspend)
		run_cmd --suspend --lock
        ;;
    $hibernate)
		run_cmd --hibernate --lock
        ;;
esac
