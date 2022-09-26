FROM fedora as assets
RUN dnf install -y make python git gcc automake autoconf libcap-devel \
    systemd-devel yajl-devel libseccomp-devel pkg-config \
    go-md2man glibc-static python3-libmount libtool
RUN curl https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s -- -p /usr/local --version=0.11.0 \
    && git clone --depth 1 --branch 1.6 https://github.com/containers/crun.git \
    && cd crun \
    && ./autogen.sh \
    && ./configure --with-wasmedge --enable-embedded-yajl\
    && make

FROM fedora 
COPY --from=assets /crun/crun /assets/crun
COPY --from=assets /usr/local/lib/libwasmedge.so /assets/libwasmedge.so

RUN dnf install -y qemu libguestfs-tools
COPY install_wasmedge.guestfish /assets/install_wasmedge.guestfish
WORKDIR /work

CMD curl -L https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/36.20220906.3.2/x86_64/fedora-coreos-36.20220906.3.2-qemu.x86_64.qcow2.xz |unxz > fedora-coreos-36.20220906.3.2-qemu.x86_64.qcow2 \
    && LIBGUESTFS_BACKEND=direct guestfish -a fedora-coreos-36.20220906.3.2-qemu.x86_64.qcow2 -m /dev/sda4 -f /assets/install_wasmedge.guestfish \
    && chmod 666 fedora-coreos-36.20220906.3.2-qemu.x86_64.qcow2