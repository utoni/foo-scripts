#!/bin/sh

####################################################################
# This is a simple Buildroot helper script. Place this script into #
# your Buildroot directory.                                        #
# If you want any features to be added or found some bugs or       #
# feedback, feel free to mail me some words:                       #
#      matzeton@googlemail.com                                     #
#                                                                  #
# gl&hf                                                            #
####################################################################

NAME=`basename $0`
DIRNAME=`dirname $0`
OLDPWD=`pwd`
BACKUP_DIR="$DIRNAME/bck"
BACKUP_SRCS="fs/minlin_skel minlin_buildroot.config minlin_kernel_i386.config minlin_uclibc.config minlin_busybox.config package/sysvinit package/ncurses package/htop package/squid package/libpth package/pppd package/openssh package/iptables package/tor target"

BR_KERNEL="$DIRNAME/output/images/bzImage"
BR_ROOTFS="$DIRNAME/output/images/rootfs.ext2"
BR_INITRD="$DIRNAME/output/images/rootfs.cpio"

TARGET_DIR="$DIRNAME/output/target"
STAGING_DIR="$DIRNAME/output/staging"
STAMP_DIR="$DIRNAME/output/stamps"
BUILD_DIR="$DIRNAME/output/build"




print() {
        echo "> $NAME: $1."
}

usage() {
        cat << EOF


$NAME [arg0]

  help          -       this
  make          -       make
  rebuild       -       rebuild target
  backup        -       create backup dir
  restore       -       restore files from backup dir
  br            -       Buildroot menuconfig
  bbox          -       make busybox-menuconfig
  uclibc        -       make uclibc-menuconfig
  linux         -       make linux-menuconfig

  qemu -[argN]  -       start qemu with buildroot kernel
    where [argN] can be:
      i         -       start qemu with kernel & initrd
      s         -       using stdio for input/output
      n         -       append init=/bin/sh
      r         -       using ext2 rootfs
      x         -       extra append parameter

EOF
}


clean_conf() {
        [ -z "$BACKUP_DIR" ] && print '$BACKUP_DIR var missing' && return 1
        print 'cleaning up'
        rm -rf "$BACKUP_DIR" 2>/dev/null
}

backup_conf() {
        [ -z "$BACKUP_SRCS" ] && print 'missing $BACKUP_SRCS' && return 1

        clean_conf
        mkdir -p "$BACKUP_DIR"
        for bck_obj in $BACKUP_SRCS; do
                [ -e "$DIRNAME/$bck_obj" ] || {
                        print "nonexisting object $DIRNAME/$bck_obj"
                        continue
                }

                dir=`dirname "$BACKUP_DIR/$bck_obj"`
                mkdir -p "$dir"
                [ -f "$DIRNAME/$bck_obj" -a -r "$DIRNAME/$bck_obj" ] && {
                        print "backup file $DIRNAME/$bck_obj"
                        cp "$DIRNAME/$bck_obj" "$BACKUP_DIR/$bck_obj"
                } || {
                        print "backup dir $DIRNAME/$bck_obj"
                        cp -rf "$DIRNAME/$bck_obj" "$dir"
                }
        done
}

restore_conf() {
        [ -z "$BACKUP_DIR" ] && print '$BACKUP_DIR var missing' && return 1
        [ -z "$BACKUP_SRCS" ] && print 'missing $BACKUP_SRCS' && return 2
        for bck_obj in $BACKUP_SRCS; do
                print "restoring object $DIRNAME/$bck_obj"
                rm -rf "$DIRNAME/$bck_obj"
                cp -rf "$BACKUP_DIR/$bck_obj" "$DIRNAME/$bck_obj"
        done
}


start_qemu() {
BIN=
APPEND=

[ -x /usr/bin/kvm ] && BIN=/usr/bin/kvm || BIN=/usr/bin/qemu

while getopts isnrx: opt
do
    case "$opt" in
        i) INITRD="-initrd $BR_INITRD" ;;
        s) SERIAL="-serial stdio" ;;
        n) APPEND="$APPEND init=/bin/sh" ;;
        r) ROOTFS="-hda $BR_ROOTFS -boot c" ;;
        x) [ -z $2 ] || APPEND="$APPEND $2" ;;
    esac
done

print "starting $BIN"
print "kernel: $BR_KERNEL"
print "parameter: $ROOTFS $INITRD $SERIAL -append \"$APPEND\""

$BIN -kernel $BR_KERNEL -m 512 -localtime -no-reboot -name brlinux -net none $ROOTFS $INITRD $SERIAL -append "$APPEND"
}

[ -r "$DIRNAME/Makefile" ] || {
  print "No Makefile in $DIRNAME"
  print "Please copy me in the Buildroot dir"
  exit 1
}
[ $# -gt 0 ] && {
  print "init"
  print "cd to $DIRNAME"
  cd "$DIRNAME"
}

case "$1" in
        make)   print "make all"
                make
                break
        ;;
        rebuild)
                print "rebuild target/rootfs"
                rm -f output/build/.root
                find ./output -name ".stamp_target_installed*" -print | xargs rm -f
                make
        ;;
        bck|backup)
                print "backup"
                backup_conf
                break
        ;;
        rst|restore)
                print "restore"
                restore_conf
                break
        ;;
        br|b)   print "make menuconfig"
                make menuconfig
                break
        ;;
        busybox|bbox|bb)
                print "make busybox"
                make busybox-menuconfig
                break
        ;;
        uclibc|libc)    print "make uclibc"
                make uclibc-menuconfig
                break
        ;;
        linux|kernel|lin)
                print "make linux"
                make linux-menuconfig
                break
        ;;
        qemu|kvm)
                print "start qemu/kvm"
                start_qemu $2 $3
                break
        ;;
        *)      usage
                break
        ;;
esac

[ $# -gt 0 ] && {
  print "cd back to $OLDPWD"
  cd "$OLDPWD"
}
