#!/bin/sh
set -e


SSHFS_DST="router"
SSHFS_DIR="${HOME}/sshfs"
SSHFS_TRG="${HOME}/git/freetz/images/backup.tar.gz"

echo "$0: ${SSHFS_DST}:/var/media/ftp --> ${SSHFS_DIR} --> ${SSHFS_TRG}"
mkdir -p ${SSHFS_DIR}
sshfs "${SSHFS_DST}:/var/media/ftp" "${SSHFS_DIR}"
tar -C ${SSHFS_DIR} -cvzf "${SSHFS_TRG}" .
fusermount -u ${SSHFS_DIR}

dst=$(dirname ${SSHFS_TRG})/config.txt
echo "$0: /etc/.config --> ${dst}"
scp "${SSHFS_DST}:/etc/.config" "${dst}"

exit 0
