#!/bin/bash

read -p "User: " user
read -p "Target: " target
if [ "x${user}" != "x" ]; then
	ssh -L "4713:127.0.0.1:4713" "${user}@${target}" -o "ExitOnForwardFailure yes"
	export PULSE_SERVER="127.0.0.1"
else
	export PULSE_SERVER="${target}"
fi
$*
