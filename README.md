# wwMpi
an attempt to automate the installation and configuration of a cluster with warewulf and mpich

Guidelines for Creating Debian 7.11 Linux Cluster
####
#  Create USB bootable linux install
#  First: download debian “wheezy” amd64 netinstall iso from
# https://www.debian.org/releases/oldstable/debian-installer/ (Links to an external site.)Links to an external site.
# insert usb stick, find out where it is mounted (on Mac):
#  (for example, my usb shows mounted on /dev/disk3)

ls /Volumes
diskutil list

# Partially unmount the usb stick:
diskutil unmountDisk /dev/disk3

# Write debian image to USB stick (this will take several minutes):
sudo dd if=debian-7.11.0-amd64-netinst.iso of=/dev/disk3 bs=1m

# For a simple installation on a single drive, use the following primary partitioning scheme:
/boot (~16 GB, ext4)
Swap (2x Physical Memory)
/ (~200 GB, ext4)
/usr (~200 GB, ext4)
(Semi-optional:)
/home (~500 GB, ext4)
/usr/local (depends on how much custom/source installations you’ll have)
/scratch (common computing filespace)
(Not semi-optional; i.e., mandatory for true production systems:)
/tmp (????)

# For the installation process, you’ll typically choose eth0 (external NIC) and DHCP to be autoconfigured.  Nothing needs to be done for eth1.

# Create a root user account and a regular user account.  Remember the passwords for both.
# Install base system for Debian Linux on master node.  Select: Debian Desktop environment, SSH server, Standard system utils
# update the base system (as root user) when it reboots, via:
apt-get update
apt-get upgrade

# download warewulf/mpich installer
# then as root   
cd /home/***user***/Downloads
git https://github.com/wesleychildress/wwMpi
cd wwMpi
cp -r * ~
cd ~
./install.sh

# Your final networking routing can be checked with:
ip route

# and should resemble:
default via 136.160.116.1 dev eth0  proto static
10.253.1.0/24 dev eth1  proto kernel scope link  src 10.253.1.254
136.160.116.0/22 dev eth0  proto kernel scope link src 136.160.119.40

# Verify the appropriate nfs filesystems are being exported by the master node:
showmount -e 10.253.1.254

# add first compute node, named ‘n0001’ with the appropriate HW (MAC) address:

wwsh node new n0001 --hwaddr=b8:ac:6f:32:37:08 --ipaddr=10.253.1.1

# Note, if you have trouble booting compute nodes over tftpd from here, it may be that the switch has bad arp info - so, restart the switch

# Check that nfs mounts are working on compute nodes, and that they are mounted
#and preserving file/directory permissions (as root):

ssh n0001
df -k
ls -ltra /home


# Examine ownership and permissions of mounts, including /home
# Create Non-root (non-privileged) user account, then setup for ssh with password-less login:

su (non-root username)

cd
ssh-keygen -t rsa
(enter no passphrase)
cd ~/.ssh
cp id_rsa.pub authorized_keys
cd
ssh n0001
(answer yes)
Exit
ssh n0001

# No prompt/password should happen for the second ssh

#NOTE: If you have a kernel upgrade in this, you may need to update the bootstrap image by executing the following commands:

wwbootstrap 3.21.6

wwsh provision set n0001 --vnfs=debian7 --bootstrap=3.21.6-4-amd64


# reboot n0001, then ssh into n0001 and check that ntp info is being picked up by the compute

# nodes:

ntpq

ntpq> peers



# manually add new nodes by individually executing each of the following commands:

wwsh node new n0002 --hwaddr=b8:ac:6f:34:b2:fd --ipaddr=10.253.1.11

wwsh node new n0003 --hwaddr=b8:ac:6f:34:62:c7 --ipaddr=10.253.1.3

wwsh node new n0004 --hwaddr=b8:ac:6f:34:65:72 --ipaddr=10.253.1.4

wwsh node new n0005 --hwaddr=b8:ac:6f:32:2e:d4 --ipaddr=10.253.1.5


# Make sure all of the new nodes have their hostnames added to the ssh config files by logging #  into them manually over ssh, which should prompt for their addition to the files


# confirm that pdsh will execute a command in parallel across an initial set of four compute nodes, as a root and as a normal user:

# (https://code.google.com/p/pdsh/wiki/UsingPDSH (Links to an external site.)Links to an external site.)



pdsh -R ssh -w (masternodename),n0001 hostname

pdsh -R ssh -w (masternodename),n0001 uname -a



# Optional: install rsyslogd on compute nodes if needed:
chroot /srv/chroots/debian7
mount -t proc proc proc/
apt-get install rsyslog
wwvnfs --chroot /srv/chroots/debian7  --hybridpath=/vnfs
wwsh dhcp update

# then restart compute nodes

# Make sure /usr/local/lib is in library path on all nodes, perhaps through the addition of

# /usr/local/lib to the file /srv/chroots/debian7/etc/ld.so.conf.d/libc.conf  file

# Reboot all compute nodes:

pdsh -R ssh -w n0001,n0002,n0003,n0004 reboot
# Reboot master node
# login as non-root user, create file hello.c



#include <stdio.h>
#include <mpi.h>

int main(int argc, char ** argv) {
int size,rank;
int length;
char name[80];
MPI_Status status;
int i;

MPI_Init(&argc, &argv);
// note that argc and argv are passed by address
MPI_Comm_rank(MPI_COMM_WORLD,&rank);
MPI_Comm_size(MPI_COMM_WORLD,&size);
MPI_Get_processor_name(name,&length);
if (rank==0) {
    // server commands
printf("Hello MPI from the server process!\n");
for (i=1;i<size;i++) {
MPI_Recv(name,80,MPI_CHAR,i,999,MPI_COMM_WORLD,&status);
printf("Hello MPI!\n");
printf(" mesg from %d of %d on %s\n",i,size,name);
}
}
else {    // client commands
MPI_Send(name,80,MPI_CHAR,0,999,MPI_COMM_WORLD);

}
MPI_Finalize();
}

# Compile executable:
mpicc -o hello.out hello.c

# Run the executable as non-root user:
mpirun -hosts (masternodename),n0001 -n 12 ./hello.out
