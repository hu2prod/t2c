#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y htop atop iotop screen tmux mc git nano curl wget g++ build-essential gcc make cmake autoconf automake psmisc pciutils lm-sensors ethtool net-tools mtr-tiny expect moreutils autossh

echo "vbell on"             >> ~/.screenrc
echo "vbell_msg ''"         >> ~/.screenrc
echo "termcapinfo *  vb=:"  >> ~/.screenrc
