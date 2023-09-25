#!/bin/sh
home-manager switch --flake .#$1 --extra-experimental-features nix-command --extra-experimental-features flakes
