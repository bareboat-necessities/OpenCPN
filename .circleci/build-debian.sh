#!/usr/bin/env bash

#
# Build for Debian in a docker container
#

# bailout on errors and echo commands.
set -xe

DOCKER_SOCK="unix:///var/run/docker.sock"

echo "DOCKER_OPTS=\"-H tcp://127.0.0.1:2375 -H $DOCKER_SOCK -s devicemapper\"" | sudo tee /etc/default/docker > /dev/null
sudo service docker restart
sleep 5;

if [ "$EMU" = "on" ]; then
  if [ "$CONTAINER_DISTRO" = "raspbian" ]; then
      docker run --rm --privileged multiarch/qemu-user-static:register --reset
  else
      docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
  fi
fi

WORK_DIR=$(pwd):/ci-source

docker run --privileged -d -ti -e "container=docker"  -v $WORK_DIR:rw $DOCKER_IMAGE /bin/bash
DOCKER_CONTAINER_ID=$(docker ps --last 4 | grep $CONTAINER_DISTRO | awk '{print $1}')

wget -q https://ftp-master.debian.org/keys/release-10.asc -O- | sudo apt-key add -
echo "deb http://deb.debian.org/debian buster non-free" | sudo tee -a /etc/apt/sources.list
sudo apt update

docker exec --privileged -ti $DOCKER_CONTAINER_ID apt-get update
docker exec --privileged -ti $DOCKER_CONTAINER_ID apt-get -y install apt-transport-https

docker exec --privileged -ti $DOCKER_CONTAINER_ID /bin/bash -xec \
  "wget -q 'https://dl.cloudsmith.io/public/bbn-projects/bbn-repo/cfg/gpg/gpg.070C975769B2A67A.key' -O- | apt-key add -"
docker exec --privileged -ti $DOCKER_CONTAINER_ID /bin/bash -xec \
  "wget -q 'https://dl.cloudsmith.io/public/bbn-projects/bbn-repo/cfg/setup/config.deb.txt?distro=raspbian&codename=buster' -O- > /etc/apt/sources.list.d/bbn-projects-bbn-repo.list"

docker exec --privileged -ti $DOCKER_CONTAINER_ID apt-get update
docker exec --privileged -ti $DOCKER_CONTAINER_ID apt-get -y install autotools-dev autoconf dh-exec cmake gettext git-core \
    libgtk-3-dev                           \
    libgl1-mesa-dev                        \
    libglu1-mesa-dev                       \
    libgtk2.0-dev                          \
    zlib1g-dev                             \
    libjpeg-dev                            \
    libpng-dev                             \
    libtiff5-dev                           \
    libsm-dev                              \
    libexpat1-dev                          \
    libxt-dev                              \
    libgstreamer1.0-dev                    \
    libgstreamer-plugins-base1.0-dev       \
    libwebkit2gtk-4.0-dev                  \
    libnotify-dev                          \
    wget                                   \
    doxygen                                \
    graphviz                               \
    meson                                  \
    bc                                     \
    bison                                  \
    flex                                   \
    at-spi2-core                           \
    libglib2.0-doc                         \
    libatk-bridge2.0-dev                   \
    libatk1.0-dev                          \
    libcairo2-dev                          \
    libegl1-mesa-dev                       \
    libepoxy-dev                           \
    libfontconfig1-dev                     \
    libfribidi-dev                         \
    libharfbuzz-dev                        \
    libpango1.0-dev                        \
    libwayland-dev                         \
    libxcomposite-dev                      \
    libxcursor-dev                         \
    libxdamage-dev                         \
    libxext-dev                            \
    libxfixes-dev                          \
    libxi-dev                              \
    libxinerama-dev                        \
    libxkbcommon-dev                       \
    libxml2-utils                          \
    libxrandr-dev                          \
    wayland-protocols                      \
    libatk1.0-doc                          \
    libpango1.0-doc                        \
    adwaita-icon-theme                     \
    dh-sequence-gir                        \
    fonts-cantarell                        \
    gnome-pkg-tools                        \
    gobject-introspection                  \
    gsettings-desktop-schemas              \
    gtk-doc-tools                          \
    libcolord-dev                          \
    libcups2-dev                           \
    libgdk-pixbuf2.0-dev                   \
    libgirepository1.0-dev                 \
    libjson-glib-dev                       \
    librest-dev                            \
    librsvg2-common                        \
    libxkbfile-dev                         \
    sassc                                  \
    xauth                                  \
    xvfb                                   \
    docbook-xml                            \
    docbook-xsl                            \
    libcairo2-doc                          \
    libc6                                  \
    libglib2.0-0                           \
    libjson-glib-1.0-0                     \
    libxcomposite1                         \
    xsltproc                               \
    libgdk-pixbuf2.0-bin                   \
    libgdk-pixbuf2.0-common                \
    libgdk-pixbuf2.0-0                     \
    gir1.2-gdkpixbuf-2.0                   \
    libgdk-pixbuf2.0-dev                   \
    libgtk-3-common                        \
    libgtk-3-0                             \
    gir1.2-gtk-3.0                         \
    libgtk-3-dev                           \
    libwxbase3.1                           \
    libwxbase3.1-dev                       \
    libwxgtk3.1                            \
    libwxgtk3.1-dev                        \
    libwxgtk3.1-gtk3                       \
    libwxgtk3.1-gtk3-dev                   \
    libwxgtk-media3.1                      \
    libwxgtk-media3.1-dev                  \
    libwxgtk-media3.1-gtk3                 \
    libwxgtk-media3.1-gtk3-dev             \
    libwxgtk-webview3.1-gtk3               \
    libwxgtk-webview3.1-gtk3-dev           \
    wx3.1-headers                          \
    wx3.1-i18n                             \
    wx-common

docker exec -ti $DOCKER_CONTAINER_ID /bin/bash -xec \
    "cd ci-source; dpkg-buildpackage -b -uc -us; mkdir dist; mv ../*.deb dist; chmod -R a+rw dist"

find dist -name \*.deb

echo "Stopping"
docker ps -a
docker stop $DOCKER_CONTAINER_ID
docker rm -v $DOCKER_CONTAINER_ID
