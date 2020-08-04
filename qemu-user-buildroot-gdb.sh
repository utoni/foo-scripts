#!/usr/bin/env sh

SYSROOT="${1}"
EXEC="${2}"

if [ -z "${SYSROOT}" -o -z "${EXEC}" ]; then
    printf 'usage: NOCHROOT=[0|1] GDB=[0|1] %s [BUILDROOT-BUILDDIR] [BINARY-YOU-WANT-TO-DEBUG]\n' "${0}"
    exit 1
fi

SOLIB_SEARCH_PATHS="$(patchelf --print-rpath "${EXEC}")"

gdb-multiarch -q --nh \
    -ex "auto-load safe-path" \
    -ex "add-auto-load-safe-path $debugdir:$datadir/auto-load" \
    -ex "set solib-search-path ${SOLIB_SEARCH_PATHS}" \
    -ex "set sysroot ${SYSROOT}/output/target" \
    -ex "file ${EXEC}" \
    -ex 'target remote localhost:31337'
