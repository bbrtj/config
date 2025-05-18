#!/bin/sh
# Print a fortune cookie for interactive shells:

case $- in
*i* )  # We're interactive
  rand=$(($RANDOM % 100))
  if [ $rand -ge 90 ]; then
    fortune fortunes fortunes2 linuxcookie | cowsay -f camel
  echo
  fi
  ;;
esac

