#!/bin/bash

if [ $EUID != 0 ]; then
    echo "This script requires sudo, so it might not work."
fi

set -e

if [ -z "$CLOCKWORK_IMAGE" ]; then
    echo "Please set CLOCKWORK_IMAGE to the path to the output image."
    exit 1
fi

if [[ "$CLOCKWORK_IMAGE" != /* ]]; then
    CLOCKWORK_IMAGE=$SKIFF_ROOT_DIR/$CLOCKWORK_IMAGE
fi

echo "Allocating sparse image..."
fallocate -l 1.5G $CLOCKWORK_IMAGE

echo "Setting up loopback device..."
export CLOCKWORK_SD=$(losetup --show -fP $CLOCKWORK_IMAGE)
function cleanup {
  echo "Removing loopback device..." || true
  sync || true
  losetup -d $CLOCKWORK_SD || true
}
trap cleanup EXIT

if [ -z "${CLOCKWORK_SD}" ] || [ ! -b ${CLOCKWORK_SD} ]; then
    echo "Failed to setup loop device."
    exit 1
fi

export SKIFF_NO_INTERACTIVE=1
export DISABLE_CREATE_SWAPFILE=1

echo "Using loopback device at ${CLOCKWORK_SD}"
$SKIFF_CURRENT_CONF_DIR/scripts/format_sd.sh
$SKIFF_CURRENT_CONF_DIR/scripts/install_sd.sh
