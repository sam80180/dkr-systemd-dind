#
# Container running systemd and docker-in-docker.  Useful for
# simulating multinode deployments of [container orchestration
# system].
#
# The standard name for this image is maru/systemd-dind
#
# Notes:
#
#  - disable SELinux on the docker host (not compatible with dind)
#
#  - to use the overlay graphdriver, ensure the overlay module is
#    installed on the docker host
#
#      $ modprobe overlay
#
#  - run with --privileged
#
#      $ docker run -d --privileged maru/systemd-dind:ubuntu18.04
#

FROM ubuntu:18.04
MAINTAINER marun@redhat.com/sam80180

# Fix 'WARNING: terminal is not fully functional' when TERM=dumb
ENV TERM=xterm

## Configure systemd to run in a container

ENV container=docker

VOLUME ["/run", "/tmp"]

STOPSIGNAL SIGRTMIN+3

RUN apt-get update && apt-get install -y systemd iptables
#RUN cd /lib/systemd/system/sysinit.target.wants/; for i in *; do test "${i}" = "systemd-tmpfiles-setup.service" || rm -f $i; done; \
#	rm -f /lib/systemd/system/multi-user.target.wants/*; \
#	rm -f /etc/systemd/system/*.wants/*; \
#	rm -f /lib/systemd/system/local-fs.target.wants/*; \
#	rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
#	rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
#	rm -f /lib/systemd/system/basic.target.wants/*; \
#	rm -f /lib/systemd/system/anaconda.target.wants/*

#RUN systemctl mask\
#	console-getty.service\
#	dev-hugepages.mount\
#	getty.target\
#	sys-fs-fuse-connections.mount\
#	systemd-logind.service\
#	systemd-remount-fs.service\
RUN cp /lib/systemd/system/dbus.service /etc/systemd/system/;\
	sed -i 's/OOMScoreAdjust=-900//' /etc/systemd/system/dbus.service

# https://kubernetes.io/docs/setup/cri/#docker
RUN apt-get install -y apt-transport-https ca-certificates curl software-properties-common && \
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

RUN apt-get update && apt-get install -y docker-ce=18.06.2~ce~3-0~ubuntu

# Configure docker

RUN systemctl enable docker.service

# Default storage to vfs.  overlay will be enabled at runtime if available.
RUN mkdir -p /etc/docker
COPY etc/docker/daemon.json /etc/docker/daemon.json

COPY dind-setup.sh /usr/local/bin
COPY dind-setup.service /etc/systemd/system/
RUN systemctl enable dind-setup.service

VOLUME ["/var/lib/docker"]

# Hardlink init to another name to avoid having oci-systemd-hooks
# detect containers using this image as requiring read-only cgroup
# mounts.  containers running docker need to be run with --privileged
# to ensure cgroups are mounted with read-write permissions.
RUN ln /sbin/init /usr/sbin/dind_init

ENTRYPOINT ["/usr/sbin/dind_init"]

# limpiar
RUN apt-get clean ; history -c; rm -f ~/.bash_history
