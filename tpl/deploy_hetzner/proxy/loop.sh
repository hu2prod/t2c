#!/bin/bash

# npm run dev ctrl-c will kill only $* command
trap ctrl_c INT

function ctrl_c() {
  echo "Shutdown on CTRL-C"
  exit
}

# TODO uncomment this if you have problems with your env
# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
# nvm use 6.6.0

while :
do
  $*
  echo "restart"
  sleep 0.2
done
