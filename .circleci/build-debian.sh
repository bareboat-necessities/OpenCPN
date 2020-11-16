#!/usr/bin/env bash

#
# Build for Debian in a docker container
#

# bailout on errors and echo commands.
set -xe

DOCKER_SOCK="unix:///var/run/docker.sock"

echo "DOCKER_OPTS=\"-H tcp://127.0.0.1:2375 -H $DOCKER_SOCK -s overlay2\"" | sudo tee /etc/default/docker > /dev/null
sudo service docker restart
sleep 5;

if [ "$EMU" = "on" ]; then
  if [ "$CONTAINER_DISTRO" = "raspbian" ]; then
      docker run --rm --privileged multiarch/qemu-user-static:register --reset
  else
      docker run --rm --privileged --cap-add=ALL --security-opt="seccomp=unconfined" multiarch/qemu-user-static --reset --credential yes --persistent yes
  fi
fi

WORK_DIR=$(pwd):/ci-source

docker run --privileged --cap-add=ALL --security-opt="seccomp=unconfined" -d -ti -e "container=docker"  -v $WORK_DIR:rw $DOCKER_IMAGE /bin/bash
DOCKER_CONTAINER_ID=$(docker ps --last 4 | grep $CONTAINER_DISTRO | awk '{print $1}')

docker exec --privileged -ti $DOCKER_CONTAINER_ID apt-get update
docker exec --privileged -ti $DOCKER_CONTAINER_ID apt-get -y install apt-transport-https wget curl gnupg2

docker exec --privileged -ti $DOCKER_CONTAINER_ID /bin/bash -xec \
  "wget -q 'https://dl.cloudsmith.io/public/bbn-projects/bbn-repo/cfg/gpg/gpg.070C975769B2A67A.key' -O- | apt-key add -"
docker exec --privileged -ti $DOCKER_CONTAINER_ID /bin/bash -xec \
  "wget -q 'https://dl.cloudsmith.io/public/bbn-projects/bbn-repo/cfg/setup/config.deb.txt?distro=${PKG_DISTRO}&codename=${PKG_RELEASE}' -O- | tee -a /etc/apt/sources.list"

docker exec --privileged -ti $DOCKER_CONTAINER_ID apt-get update
docker exec -ti $DOCKER_CONTAINER_ID apt-get -y install dpkg-dev debhelper devscripts equivs pkg-config apt-utils fakeroot
docker exec --privileged -ti $DOCKER_CONTAINER_ID apt-get -y install autotools-dev autoconf dh-exec cmake gettext git-core \
    libgps-dev                             \
    libglu1-mesa-dev                       \
    libarchive-dev                         \
    libexpat1-dev                          \
    libcairo2-dev                          \
    libbz2-dev                             \
    libssl-dev                             \
    libcurl4-openssl-dev                   \
    libdrm-dev                             \
    libelf-dev                             \
    libexif-dev                            \
    liblz4-dev                             \
    liblzma-dev                            \
    libpango1.0-dev                        \
    libsqlite3-dev                         \
    libtinyxml-dev                         \
    libunarr-dev                           \
    lsb-release                            \
    libportaudio2                          \
    portaudio19-dev                        \
    libgtk-3-dev                           \
    wx-common                              \
    wx3.1-headers                          \
    wx3.1-i18n                             \
    libwxgtk3.1-gtk3-dev                   \
    libwxsvg-dev

docker exec --privileged -ti $DOCKER_CONTAINER_ID apt-get -y remove libwxgtk3.0-0v5

docker exec --privileged -ti $DOCKER_CONTAINER_ID ldconfig

docker exec -ti $DOCKER_CONTAINER_ID /bin/bash -xec \
    "update-alternatives --set wx-config /usr/lib/*-linux-*/wx/config/gtk3-unicode-3.1"

docker exec -ti $DOCKER_CONTAINER_ID /bin/bash -xec \
    "update-alternatives --set fakeroot /usr/bin/fakeroot-tcp; cd ci-source; dpkg-buildpackage -b -uc -us -j2; mkdir dist; mv ../*.deb dist; chmod -R a+rw dist"

find dist -name \*.\*$EXT

echo "Stopping"
docker ps -a
docker stop $DOCKER_CONTAINER_ID
docker rm -v $DOCKER_CONTAINER_ID
