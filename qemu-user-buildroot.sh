#!/usr/bin/env sh

set -e
set -x
set -o pipefail

BUILDROOT_BUILDDIR="${1}"
QEMU_STATIC_BIN="${2}"
TEST_BIN="${3}"

BUILDROOT_TARGETDIR="${BUILDROOT_BUILDDIR}/output/target"

retval=0

if [ -z "${BUILDROOT_BUILDDIR}" -o -z "${QEMU_STATIC_BIN}" -o -z "${TEST_BIN}" ]; then
    printf 'usage: NOCHROOT=[0|1] GDB=[0|1] %s [BUILDROOT-BUILD-DIR] [QEMU-STATIC-BIN] [BINARY-YOU-WANT-TO-EXECUTE]\n' "${0}"
    exit 1
fi

if [ ! -r "${BUILDROOT_TARGETDIR}/THIS_IS_NOT_YOUR_ROOT_FILESYSTEM" ]; then
    printf '%s: Not a buildroot target directory: %s\n' "${0}" "${BUILDROOT_TARGETDIR}/THIS_IS_NOT_YOUR_ROOT_FILESYSTEM"
    retval=2
fi

if [ ! -x "${QEMU_STATIC_BIN}" ]; then
    printf '%s: Not an executable: %s\n' "${0}" "${QEMU_STATIC_BIN}"
    retval=2
fi

if [ ! -x "${TEST_BIN}" ]; then
    printf '%s: Not an executable: %s\n' "${0}" "${TEST_BIN}"
    retval=2
fi

if [ ${retval} -ne 0 ]; then
    exit ${retval}
fi

# set rpath and copy test binary to target directory
TEST_BIN_BNAME="$(basename "${TEST_BIN}")"
cp "${TEST_BIN}" "${BUILDROOT_TARGETDIR}/${TEST_BIN_BNAME}"

QEMU_BNAME="$(basename "${QEMU_STATIC_BIN}")"
cp "${QEMU_STATIC_BIN}" "${BUILDROOT_TARGETDIR}/${QEMU_BNAME}"
mkdir -p "${BUILDROOT_TARGETDIR}/home"

if [ ! -z "${NOCHROOT}" ]; then
SUDO=''
CMDS="'${QEMU_STATIC_BIN}' -L '${BUILDROOT_TARGETDIR}' '${TEST_BIN}'"
elif [ ! -z "${GDB}" ]; then
SUDO=''
CMDS="'${QEMU_STATIC_BIN}' -L '${BUILDROOT_TARGETDIR}' -g 31337 '${TEST_BIN}'"
else
SUDO='sudo'
CMDS=$(cat << EOF
mount -t proc /proc "${BUILDROOT_TARGETDIR}/proc"
chroot . "/${QEMU_BNAME}" /bin/su -l nobody -s /bin/ash
umount "${BUILDROOT_TARGETDIR}/proc"
EOF
)
fi

cd "${BUILDROOT_TARGETDIR}"

${SUDO} ${SHELL} -c "${CMDS}"
