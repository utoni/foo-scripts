#!/bin/bash

if [ $(id -u) -eq 0 ]; then
  echo "* Dont run this script as root!"
  exit 1
fi
virtualenv --python=/usr/bin/python3 ~/mps-youtube --no-site-packages
source ~/mps-youtube/bin/activate
pip install mps-youtube
