#!/bin/sh

##
# Install ninja, autoconf, automake and libtool for macOS
##

export build=`pwd`/temp # or wherever you'd like to build
export install=`pwd`/tools
mkdir -p $build

##
# Ninja
# https://github.com/ninja-build/ninja

cd $build
curl -OL https://github.com/ninja-build/ninja/releases/download/v1.10.2/ninja-mac.zip
unzip ninja-mac.zip
mkdir -p $install/bin/
mv ninja $install/bin/

##
# Autoconf
# http://ftpmirror.gnu.org/autoconf

cd $build
curl -OL http://ftpmirror.gnu.org/autoconf/autoconf-2.69.tar.gz
tar xzf autoconf-2.69.tar.gz
cd autoconf-2.69
./configure --prefix=$install
make
make install

##
# Automake
# http://ftpmirror.gnu.org/automake

cd $build
curl -OL http://ftpmirror.gnu.org/automake/automake-1.15.tar.gz
tar xzf automake-1.15.tar.gz
cd automake-1.15
./configure --prefix=$install
make
make install

##
# Libtool
# http://ftpmirror.gnu.org/libtool

cd $build
curl -OL http://ftpmirror.gnu.org/libtool/libtool-2.4.6.tar.gz
tar xzf libtool-2.4.6.tar.gz
cd libtool-2.4.6
./configure --prefix=$install
make
make install

echo "Installation complete. Make sure to add $install/bin to your PATH"
