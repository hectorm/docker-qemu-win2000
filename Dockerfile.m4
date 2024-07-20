m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

FROM --platform=${BUILDPLATFORM} docker.io/ubuntu:24.04 AS build

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		binutils-mingw-w64-i686 \
		ca-certificates \
		curl \
		gcc-mingw-w64-i686 \
		genisoimage \
		make \
		p7zip-full \
		qemu-system-x86 \
		qemu-utils \
	&& rm -rf /var/lib/apt/lists/*

# Download noVNC
ARG NOVNC_VERSION=v1.5.0
ARG NOVNC_TARBALL_URL=https://github.com/novnc/noVNC/archive/${NOVNC_VERSION}.tar.gz
ARG NOVNC_TARBALL_CHECKSUM=6a73e41f98388a5348b7902f54b02d177cb73b7e5eb0a7a0dcf688cc2c79b42a
RUN curl -Lo /tmp/novnc.tgz "${NOVNC_TARBALL_URL:?}"
RUN printf '%s' "${NOVNC_TARBALL_CHECKSUM:?}  /tmp/novnc.tgz" | sha256sum -c
RUN mkdir /tmp/novnc/ && tar -xzf /tmp/novnc.tgz --strip-components=1 -C /tmp/novnc/

# Download Websockify
ARG WEBSOCKIFY_VERSION=v0.12.0
ARG WEBSOCKIFY_TARBALL_URL=https://github.com/novnc/websockify/archive/${WEBSOCKIFY_VERSION}.tar.gz
ARG WEBSOCKIFY_TARBALL_CHECKSUM=37448ec992ef626f29558404cf6535592d02894ec1d5f0990a8c62621b39a967
RUN curl -Lo /tmp/websockify.tgz "${WEBSOCKIFY_TARBALL_URL:?}"
RUN printf '%s' "${WEBSOCKIFY_TARBALL_CHECKSUM:?}  /tmp/websockify.tgz" | sha256sum -c
RUN mkdir /tmp/websockify/ && tar -xzf /tmp/websockify.tgz --strip-components=1 -C /tmp/websockify/

# Download and build srvany-ng
ARG SRVANY_NG_TARBALL_URL=https://github.com/hectorm/srvany-ng/archive/refs/tags/v1.0.tar.gz
ARG SRVANY_NG_TARBALL_CHECKSUM=62d4c85d5dbef86d57bf5d21ff913bce81b821735df293968e1706f85096c8b0
RUN curl -Lo /tmp/srvany-ng.tgz "${SRVANY_NG_TARBALL_URL:?}"
RUN printf '%s' "${SRVANY_NG_TARBALL_CHECKSUM:?}  /tmp/srvany-ng.tgz" | sha256sum -c
RUN mkdir /tmp/srvany-ng/ && tar -xzf /tmp/srvany-ng.tgz --strip-components=1 -C /tmp/srvany-ng/
RUN make -C /tmp/srvany-ng/ build

# Download and build Netcat
ARG NETCAT_TARBALL_URL=https://github.com/hectorm/netcat/archive/refs/tags/v1.14.tar.gz
ARG NETCAT_TARBALL_CHECKSUM=3cf3235a9561e456c97e43c69318f680fd86ab886324992f5655f97e846540dc
RUN curl -Lo /tmp/netcat.tgz "${NETCAT_TARBALL_URL:?}"
RUN printf '%s' "${NETCAT_TARBALL_CHECKSUM:?}  /tmp/netcat.tgz" | sha256sum -c
RUN mkdir /tmp/netcat/ && tar -xzf /tmp/netcat.tgz --strip-components=1 -C /tmp/netcat/
RUN make -C /tmp/netcat/ build

# Download and install Windows 2000 Advanced Server
# Source: https://winworldpc.com/product/windows-nt-2000/final
ARG WIN2000_ISO_URL=https://winworldpc.com/download/413dc39c-e280-9918-c39a-11c3a4e284a2/from/c3ae6ee2-8099-713d-3411-c3a6e280947e
ARG WIN2000_ISO_CHECKSUM=d0a7709f387376d64cd6f20a35c4a7ba2e4cb5f46a0a4fbd14209b4dc7a48282
RUN curl -Lo /tmp/win2000.7z "${WIN2000_ISO_URL:?}"
RUN printf '%s' "${WIN2000_ISO_CHECKSUM:?}  /tmp/win2000.7z" | sha256sum -c
RUN 7z e /tmp/win2000.7z -so '*/*.ISO' > /tmp/win2000.iso \
	&& 7z x /tmp/win2000.iso -o/tmp/win2000/ \
	&& rm -f /tmp/win2000.iso
COPY --chown=root:root ./data/iso/ /tmp/win2000/
RUN install -D /tmp/srvany-ng/srvany-ng.exe /tmp/win2000/VALUEADD/3RDPARTY/srvany-ng.exe
RUN install -D /tmp/netcat/nc.exe /tmp/win2000/VALUEADD/3RDPARTY/nc.exe
RUN sed -ri 's/^(Pid=[0-9]+)[0-9]{3}/\1270/' /tmp/win2000/I386/SETUPP.INI
RUN mkisofs -no-emul-boot -iso-level 4 -eltorito-boot '[BOOT]/Boot-NoEmul.img' -o /tmp/win2000.iso /tmp/win2000/ \
	&& qemu-img create -f qcow2 /tmp/win2000.qcow2 128G \
	&& timeout 5400 qemu-system-x86_64 \
		-machine pc -smp 2 -m 512M -accel tcg \
		-device cirrus-vga -display none -serial stdio \
		-device rtl8139,netdev=n0 -netdev user,id=n0,ipv4=on,ipv6=off,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,dhcpstart=10.0.2.15,restrict=on \
		-device ide-hd,id=disk0,bus=ide.0,drive=disk0 -blockdev driver=qcow2,node-name=disk0,file.driver=file,file.filename=/tmp/win2000.qcow2 \
		-device ide-cd,id=cd0,bus=ide.1,drive=cd0 -blockdev driver=raw,node-name=cd0,file.driver=file,file.filename=/tmp/win2000.iso,read-only=on \
		-boot order=cd,menu=off \
		-usb -device usb-tablet

##################################################
## "base" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:22.04]], [[FROM docker.io/ubuntu:22.04]]) AS base

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		catatonit \
		net-tools \
		netcat-openbsd \
		procps \
		python3 \
		qemu-system-x86 \
		qemu-utils \
		rlwrap \
		runit \
		samba \
	&& rm -rf /var/lib/apt/lists/*

# Environment
ENV VM_CPU=2
ENV VM_RAM=512M
ENV VM_KEYBOARD=en-us
ENV VM_NET_EXTRA_OPTIONS=
ENV VM_KVM=true
ENV SVDIR=/etc/service/

# Copy noVNC
COPY --from=build --chown=root:root /tmp/novnc/ /opt/novnc/

# Copy Websockify
COPY --from=build --chown=root:root /tmp/websockify/ /opt/novnc/utils/websockify/

# Copy Windows 2000 disk
COPY --from=build --chown=root:root /tmp/win2000.qcow2 /var/lib/qemu/disk/win2000.qcow2

# Copy Samba config
COPY --chown=root:root ./config/samba/ /etc/samba/
RUN find /etc/samba/ -type d -not -perm 0755 -exec chmod 0755 '{}' ';'
RUN find /etc/samba/ -type f -not -perm 0644 -exec chmod 0644 '{}' ';'

# Copy services
COPY --chown=root:root ./scripts/service/ /etc/service/
RUN find /etc/service/ -type d -not -perm 0755 -exec chmod 0755 '{}' ';'
RUN find /etc/service/ -type f -not -perm 0755 -exec chmod 0755 '{}' ';'

# Copy bin scripts
COPY --chown=root:root ./scripts/bin/ /usr/local/bin/
RUN find /usr/local/bin/ -type d -not -perm 0755 -exec chmod 0755 '{}' ';'
RUN find /usr/local/bin/ -type f -not -perm 0755 -exec chmod 0755 '{}' ';'

ENTRYPOINT ["/usr/bin/catatonit", "--", "/usr/local/bin/container-init"]

##################################################
## "test" stage
##################################################

FROM base AS test

RUN if [ "$(uname -m)" = 'x86_64' ]; then \
		container-init & \
		printf '%s\n' 'The quick brown fox jumps over the lazy dog' > /mnt/in || exit 1; \
		printf '%s\n' '@echo off & for /l %n in () do if exist Z:\in exit' | timeout 900 vmshell || exit 1; \
		printf '%s\n' '@echo off & copy Z:\in Z:\out & exit' | timeout 120 vmshell || exit 1; \
		cmp -s /mnt/in /mnt/out || exit 1; \
	fi

##################################################
## "main" stage
##################################################

FROM base AS main

# Dummy instruction so BuildKit does not skip the test stage
RUN --mount=type=bind,from=test,source=/mnt/,target=/mnt/
