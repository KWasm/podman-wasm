#!/bin/bash
URL=$1
echo "URL $URL"
FILENAME=$(basename -s .xz $URL)
curl -L $URL |unxz > $FILENAME
OS_ROOT=$(LIBGUESTFS_BACKEND=direct guestfish -a $FILENAME -m /dev/sda4 ls /ostree/deploy/fedora-coreos/deploy/|head -n 1)
sed -i s/\<OS_ROOT\>/$OS_ROOT/g /assets/install_wasmedge.guestfish 
LIBGUESTFS_BACKEND=direct guestfish -a $FILENAME -m /dev/sda4 -f /assets/install_wasmedge.guestfish