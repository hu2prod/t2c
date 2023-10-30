#!/bin/bash
while :
do
  $*
  echo "restart"
  sleep 0.2
done
