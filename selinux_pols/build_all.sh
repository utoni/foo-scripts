#!/bin/bash

BDIR=$(dirname ${0})

function run_cmd {
	cmd="${1}"
	echo "${cmd}"
	$cmd
	return $?
}

echo_cmd
echo "$0: building all in $BDIR" >&2
for file in ${BDIR}/*.te; do
	echo "* building: $file"
	fname=$(basename ${file} | sed -e 's/^\(.*\)\.\(.*\)$/\1/g')
	run_cmd "checkmodule -m -M -o ${BDIR}/${fname}.mod ${BDIR}/${fname}.te"
	if [ $? -ne 0 ]; then
		echo "checkmodule: ERROR, next .." >&2
		continue
	fi
	run_cmd "semodule_package -m ${BDIR}/${fname}.mod -o ${BDIR}/${fname}.pp"
	if [ $? -ne 0 ]; then
		echo "semodule_package: ERROR, next .." >&2
		continue
	fi
	run_cmd "semodule -i ${BDIR}/${fname}.pp"
	run_cmd "semodule -e ${fname}"
done

echo "done."
exit 0
