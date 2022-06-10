# Attempt to resize disk, if necessary.
# Note: this is an online resize, no re-mount required.
RESIZE_DISK=(embiggen-disk -verbose -ignore-resize-partition)
if [ -n "${DISABLE_RESIZE_PARTITION}" ]; then
    RESIZE_DISK+=(-no-resize-partition)
fi
if [ -z "${DISABLE_RESIZE_PERSIST}" ]; then
    echo "Resizing ${PERSIST_MNT} with embiggen-disk..."
    # This will only work with /dev/ paths.
    if [ -b ${PERSIST_DEVICE} ]; then
        # Sometimes the path does not appear in the mounts list.
        #
        # Workaround: temporarily mount it so resize2fs realizes it needs to
        # do an online resize. Otherwise returns an error.
        ROOT_MOUNT_SOURCE=$(findmnt --target / --first-only -n -o "SOURCE")
        if [ -n "${FORCE_RESIZE_PERSIST_MOUNT}" ] || \
               [[ "${ROOT_MOUNT_SOURCE}" != "${PERSIST_DEVICE}" ]] || \
               ! findmnt --source ${PERSIST_DEVICE} --first-only; then
            echo "Temporarily mounting ${PERSIST_DEVICE} to force online resize..."
            RESIZE_DISK_MTPT=/mnt/.persist-resize
            mkdir -p ${RESIZE_DISK_MTPT}
            mount ${PERSIST_DEVICE} ${RESIZE_DISK_MTPT} || true
        fi
        echo "Resizing with embiggen-disk via ${PERSIST_DEVICE}..."
        if ${RESIZE_DISK[@]} ${PERSIST_DEVICE}; then
            PERSIST_RESIZED="true"
        fi
        if [ -n "${RESIZE_DISK_MTPT}" ]; then
            echo "Unmounting ${RESIZE_DISK_MTPT}..."
            umount ${RESIZE_DISK_MTPT} || true
        fi
    fi
    if [ -z "${PERSIST_RESIZED}" ]; then
        if ! ${RESIZE_DISK[@]} ${PERSIST_MNT}; then
            echo "Failed to resize persist, continuing anyway."
        else
            PERSIST_RESIZED="true"
        fi
    fi
fi
