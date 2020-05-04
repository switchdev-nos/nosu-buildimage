#!/bin/bash

BUILDDIR="./build"
PLATFORMDIR="./platform"
ROOTDIR="$PWD"
ENVFILE=$1
BUILDENV="$BUILDDIR"/env
IMAGESDIR="./images"

KERNEL_BUILDDIR="$BUILDDIR"/nosu-kernel
PACKAGES_BUILDDIR="$BUILDDIR"/nosu-packages
ROOTFS_BUILDDIR="$BUILDDIR"/nosu-rootfs
ONIE_BUILDDIR="$BUILDDIR"/nosu-onie

fail() {
  [ -n "$1" ] && echo $1
  exit 1
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  echo "Usage: $0 [ENV_FILE]"
  exit 0
fi

if [ -n "$ENVFILE" ]; then
  if [ -r "$ENVFILE" ]; then
    set -a
    . "$ENVFILE"
    set +a
  else
    fail "ENV_FILE not readable or missing"
  fi
fi

[ -n "$NOSU_VERSION" ] || fail "NOSU_VERSION is not set"
[ -n "$NOSU_GIT_KERNEL" ] || fail "NOSU_GIT_KERNEL is not set"
[ -n "$NOSU_GIT_PACKAGES" ] || fail "NOSU_GIT_PACKAGES is not set"
[ -n "$NOSU_GIT_ROOTFS" ] || fail "NOSU_GIT_ROOTFS is not set"
[ -n "$NOSU_GIT_ONIE" ] || fail "NOSU_GIT_ONIE is not set"

if [ "$CLEAN" = true ] && [ -d "$BUILDDIR" ]; then
  echo "== Cleaning NOSU build directory"
  rm -fr "$BUILDDIR"
fi

START=$(date +%s)
mkdir -p "$BUILDDIR"

PLATFORM_ENVFILE=$PLATFORMDIR/$NOSU_PLATFORM/env/default
cp -f $ENVFILE $BUILDENV
if [ -f "$PLATFORM_ENVFILE" ]; then
  cat $PLATFORM_ENVFILE >> $BUILDENV
else
  NOSU_PLATFORM="default"
fi

clone() {
if [ -n "$1" ] && [ ! -d "$2" ]; then
  echo "== Cloning $1 ($3)"
  git clone $1 -b $3 $2
  [[ $? == 0 ]] || fail "$1 cloning failed"
fi
}

# cloning NOSU Kernel
clone $NOSU_GIT_KERNEL $KERNEL_BUILDDIR "v$NOSU_VERSION"
# cloning NOSU Packages
clone $NOSU_GIT_PACKAGES $PACKAGES_BUILDDIR "v$NOSU_VERSION"
# cloning NOSU Rootfs
clone $NOSU_GIT_ROOTFS $ROOTFS_BUILDDIR "v$NOSU_VERSION"
# cloning NOSU ONIE
clone $NOSU_GIT_ONIE $ONIE_BUILDDIR "v$NOSU_VERSION"

# building NOSU Kernel
echo "== Building NOSU Kernel"
cp -f $BUILDENV $KERNEL_BUILDDIR/env/default
pushd $KERNEL_BUILDDIR
./docker_build.sh
[[ $? == 0 ]] || fail "Kernel building failed"
popd
rsync -a "$KERNEL_BUILDDIR"/debs/*.deb --exclude=*dbg*.deb $PACKAGES_BUILDDIR/kernel/
rsync -a "$KERNEL_BUILDDIR"/debs/*.deb --exclude=*dbg*.deb $ROOTFS_BUILDDIR/kernel/

# building NOSU Packages
echo "== Building NOSU Packages"
cp -f $BUILDENV $PACKAGES_BUILDDIR/env/default
pushd $PACKAGES_BUILDDIR
./build.sh ./env/default
[[ $? == 0 ]] || fail "Packages building failed"
popd
cp -f $PACKAGES_BUILDDIR/debs/*.deb $ROOTFS_BUILDDIR/packages/

# building NOSU Rootfs
echo "== Building NOSU Rootfs"
cp -f $BUILDENV $ROOTFS_BUILDDIR/env/default
pushd $ROOTFS_BUILDDIR
./docker_build.sh
[[ $? == 0 ]] || fail "Rootfs building failed"
popd

ROOTFS_FILE="nosu-rootfs-$NOSU_VERSION.tar.$NOSU_COMPRESS"
# Building NOSU ONIE Images
cp -f $ROOTFS_BUILDDIR/image/$ROOTFS_FILE $ONIE_BUILDDIR/
[[ $? == 0 ]] || fail "Can't retrieve rootfs for ONIE image building"
pushd $ONIE_BUILDDIR
./build.sh -i $NOSU_PLATFORM $ROOTFS_FILE $NOSU_VERSION
[[ $? == 0 ]] || fail "ONIE image building failed"
popd

DATE=`date +%Y%m%d`
ONIEFILES="nosu-$NOSU_VERSION-$NOSU_PLATFORM-x86_64-${DATE}"
ONIEIMG=$ONIEFILES.bin
cp -f $ONIE_BUILDDIR/$ONIEFILES.* $IMAGESDIR/

# Finish
BUILD_SEC=$(( $(date +%s) - $START ))
BUILD_TIME=$(date -d@$BUILD_SEC -u '+%Hh %Mm %Ss')
echo "== NOSU was sucessfully built in $BUILD_TIME"
echo "== ONIE image: $IMAGESDIR/$ONIEIMG"
