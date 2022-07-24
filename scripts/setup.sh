#! /bin/sh

# Remove related kernel modules if any
sudo rmmod rdma_rxe
sudo rmmod siw
sudo modprobe -r --remove-dependencies rdma_ucm
sudo modprobe -r --remove-dependencies ib_core

set -o errexit
set -o nounset
set -o xtrace

HAS_RXE_MOD=`modprobe -c | grep rxe | cat`

if [ -z "$HAS_RXE_MOD" ]; then
    # Load required IB and RDMA kernel modules
    sudo modprobe ib_core
    sudo modprobe rdma_ucm

    export FULL_KERNEL_VERSION=`uname -r`
    export KERNEL_MAJOR_VERSION=`echo $FULL_KERNEL_VERSION | cut -d '.' -f 1`
    export LAST_VERSION_NUM=`echo ${FULL_KERNEL_VERSION%%-*} | cut -d '.' -f 3`
    if LAST_VERSION_NUM==0
    then 
        export KERNEL_VERSION=`echo ${FULL_KERNEL_VERSION%.*}`
    else
        export KERNEL_VERSION=`echo ${FULL_KERNEL_VERSION%%-*}`
    fi
    wget -q https://cdn.kernel.org/pub/linux/kernel/v$KERNEL_MAJOR_VERSION.x/linux-$KERNEL_VERSION.tar.xz
    rm -rf linux-*/ rxe/ siw/ || echo "no kernel code directory"
    tar xf linux-$KERNEL_VERSION.tar.xz

    cp -r linux-$KERNEL_VERSION/drivers/infiniband/sw/rxe/ ./rxe_build
    cp -r linux-$KERNEL_VERSION/drivers/infiniband/sw/siw/ ./siw_build

    # Build and install soft-roce kernel module
    cd ./rxe_build
    cp Makefile Makefile.orig
    mv Makefile Kbuild
    sed -i 's/$(CONFIG_RDMA_RXE)/m/g' Kbuild
    cp ../rdma-env-setup/rxe/Makefile .
    make
    sudo insmod ./rdma_rxe.ko

    # Build and install softiwarp kernel module
    cd ../siw_build
    cp Makefile Makefile.orig
    mv Makefile Kbuild
    sed -i 's/$(CONFIG_RDMA_RXE)/m/g' Kbuild
    cp ../rdma-env-setup/siw/Makefile .
    make
    sudo insmod ./siw.ko
fi
