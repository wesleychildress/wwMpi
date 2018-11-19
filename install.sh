#!/bin/bash
sudo apt-get install -f

LIST_OF_APPS="ssh ntp qt-sdk pkg-config ncurses-dev nfs-server libselinux1-dev pdsh tftp gfortran
libxml2-dev libboost-dev tk-dev apache2 libapache2-mod-perl2 tftpd-hpa debootstrap tcpdump
isc-dhcp-server curl libterm-readline-gnu-perl"

DIR=$( pwd )

# set up permanent networking connections
sudo mv -f /etc/network/interfaces /etc/network/interfaces.og
sudo cp -f $DIR/configFiles/interfaces /etc/network/interfaces
sudo /etc/init.d/networking restart

#install essential build tools:
sudo apt-get install -y build-essential

# install mariadb (new, updated mysql):
sudo apt-get install -y mysql-server mysql-client

# install other important packages:
sudo apt-get install -y $LIST_OF_APPS

sudo mv -f /etc/selinux/config /etc/selinux/config.og
sudo cp -f $( pwd )/configFiles/config /etc/selinux/config
setenforce 0

# install warewulf
cd $DIR/src
chmod +x install-wwdebsystem
./install-wwdebsystem 3.6
cd ..

# make copy of original config files then move these into place
mv -f /etc/exports /etc/exports.og
cp -f $DIR/configFiles/exports /etc/exports

mv -f /usr/local/libexec/warewulf/wwmkchroot/include-deb /usr/local/libexec/warewulf/wwmkchroot/include-deb.og
cp -f $DIR/configFiles/include-deb /usr/local/libexec/warewulf/wwmkchroot/include-deb

mv -f /usr/local/etc/warewulf/vnfs.conf /usr/local/etc/warewulf/vnfs.conf.og
cp -f $DIR/configFiles/vnfs.conf /usr/local/etc/warewulf/vnfs.conf

cp -f $DIR/configFiles/debian7.tmpl /usr/local/libexec/warewulf/wwmkchroot/debian7.tmpl

# Build and install MPICH
cd $DIR/mpich
tar zxvf mpich-3.2.1.tar.gz
cd mpich-3.2.1
./configure --enable-fc --enable-f77 --enable-romio --enable-mpe --with-pm=hydra
# make & install
make
make install

cd $DIR

# Create directories necessary for successful chrooting:
mkdir /srv/chroots
mkdir /srv/chroots/debian7
mkdir /srv/chroots/debian7/vnfs
mkdir /srv/chroots/debian7/srv
mkdir /srv/chroots/debian7/srv/chroots

# create warewulf chroot:
wwmkchroot debian7 /srv/chroots/debian7

# MINIMIZE chroot install files:
# chroot /srv/chroots/debian7
# mount -t proc proc proc/
# apt-get remove ????
# exit

# config files
mv -f /etc/idmapd.conf /etc/idmapd.conf.og
mv -f /srv/chroots/debian7/etc/idmapd.conf /srv/chroots/debian7/etc/idmapd.conf.og
cp -f $( pwd )/configFiles/idmapd.conf /etc/idmapd.conf
cp -f $( pwd )/configFiles/idmapd.conf /srv/chroots/debian7/etc/idmapd.conf

mv -f /etc/default/nfs-common /etc/default/nfs-common.og
cp -f $( pwd )/configFiles/nfs-common /etc/default/nfs-common

mv -f /usr/local/etc/warewulf/defaults/node.conf /usr/local/etc/warewulf/defaults/node.conf.og
cp -f $( pwd )/configFiles/node.conf /usr/local/etc/warewulf/defaults/node.conf

mv -f /usr/local/etc/warewulf/defaults/provision.conf /usr/local/etc/warewulf/defaults/provision.conf.og
cp -f $( pwd )/configFiles/provision.conf /usr/local/etc/warewulf/defaults/provision.conf

mv -f /usr/local/etc/warewulf/bootstrap.conf /usr/local/etc/warewulf/bootstrap.conf.og
cp -f $( pwd )/configFiles/bootstrap.conf /usr/local/etc/warewulf/bootstrap.conf

mv -f /srv/chroots/debian7/etc/fstab /srv/chroots/debian7/etc/fstab.og
cp -f $( pwd )/configFiles/fstab /srv/chroots/debian7/etc/fstab

mv -f /srv/chroots/debian7/etc/rc.local /srv/chroots/debian7/etc/rc.local.og
cp -f $( pwd )/configFiles/rc.local /srv/chroots/debian7/etc/rc.local

/bin/mount -a

# restart nfs on master node
/etc/init.d/nfs-kernel-server restart
/etc/init.d/nfs-common restart

# Restart the tftp server:
/etc/init.d/tftpd-hpa restart

# update sources
mv -f /srv/chroots/debian7/etc/apt/sources.list /srv/chroots/debian7/etc/apt/sources.list.og
cp -f $( pwd )/configFiles/sources.list /srv/chroots/debian7/etc/apt/sources.list

# We want the clocks to be the same on all nodes (synchronized)
mv -f /srv/chroots/debian7/etc/ntp.conf /srv/chroots/debian7/etc/ntp.conf.og
cp -f $( pwd )/configFiles/ntp.conf /srv/chroots/debian7/etc/ntp.conf

# update debian7 vnfs (magic land)
chroot /srv/chroots/debian7
mount -t proc proc proc/
apt-get update
apt-get upgrade
# exit

# build image
wwvnfs --chroot /srv/chroots/debian7  --hybridpath=/vnfs
wwsh dhcp update

# update the files and everything else!!!!!
wwsh file sync
wwsh dhcp update
wwsh pxe update
