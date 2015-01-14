#!/bin/bash - 
#===============================================================================
#          FILE: pxe_configure.sh
#         USAGE: ./pxe_configure.sh 
#   DESCRIPTION: Script to automate a basic centos7 pxe
#  REQUIREMENTS: centos7 OS
#        AUTHOR: (aldenso), aldenso@gmail.com
#===============================================================================
##############################
# Configuration
##############################
TFTPDIR="/var/lib/tftpboot"
IMAGEDIR="/var/www/html/centos7"
IMAGEPXE="$IMAGEDIR/images/pxeboot"
DHCPDIR="/etc/dhcp"
TFTPCONF="/etc/xinetd.d"
DHCPSERVER="192.168.100.1"
DHCPSUBNET="192.168.100.0"
DHCPSUBNETMASK="255.255.255.0"
DHCPRANGEFIRSTIP="192.168.100.150"
DHCPRANGELASTIP="192.168.100.200"
SYSLINUXDIR="/usr/share/syslinux"


##############################
# Install packages.
##############################
packages="dhcp syslinux tftp-server httpd"
yum install $packages -y > /dev/null 2>&1
if [ $? -eq 0 ]
then
	echo "Packages $packages installed successfully"
else
	echo "Failed to install Packages."
	exit 0
fi

##############################
# enable tftp in xinetd
##############################
cp tftp $TFTPCONF/tftp

##############################
# configure dhcp server
##############################
cp $DHCPDIR/dhcpd.conf $DHCPDIR/dhcpd.conf_$(date +%F-%T)
cp dhcpd.conf-template dhcpd.conf-template-orig
sed s/"subnet 192.168.100.0 netmask 255.255.255.0"/"subnet $DHCPSUBNET netmask $DHCPSUBNETMASK"/g dhcpd.conf-template > dhcpd.conf-tmp
mv dhcpd.conf-tmp dhcpd.conf-template
sed s/"range 192.168.100.231 192.168.100.253;"/"range $DHCPRANGEFIRSTIP $DHCPRANGELASTIP;"/g dhcpd.conf-template > dhcpd.conf-tmp
mv dhcpd.conf-tmp dhcpd.conf-template
sed s/"option routers 192.168.100.1;"/"option routers $DHCPSERVER;"/g dhcpd.conf-template > dhcpd.conf-tmp
mv dhcpd.conf-tmp dhcpd.conf-template
sed s/"next-server 192.168.100.1;"/"next-server $DHCPSERVER;"/g dhcpd.conf-template > dhcpd.conf-tmp
mv dhcpd.conf-tmp dhcpd.conf-template
mv dhcpd.conf-template dhcpd.conf-template-final
mv dhcpd.conf-template-orig dhcpd.conf-template
cp dhcpd.conf-template-final $DHCPDIR/dhcpd.conf
echo "###############################
DHCP configured.
###############################"

##############################
# copy syslinux templates
##############################
cp $SYSLINUXDIR/menu.c32 $SYSLINUXDIR/pxelinux.0 $SYSLINUXDIR/memdisk $SYSLINUXDIR/mboot.c32 $SYSLINUXDIR/chain.c32 $TFTPDIR
cp $IMAGEPXE/vmlinuz $IMAGEPXE/initrd.img $TFTPDIR
mkdir $TFTPDIR/pxelinux.cfg
cp default_menu $TFTPDIR/pxelinux.cfg/default
echo "###############################
TFTPBOOT configured.
###############################"

##############################
# cofigure firewall
##############################
firewall-cmd --add-service=http --permanent --zone=public > /dev/null 2>&1
firewall-cmd --add-service=tftp --permanent --zone=public > /dev/null 2>&1
firewall-cmd --add-service=dhcp --permanent --zone=public > /dev/null 2>&1
firewall-cmd --reload > /dev/null 2>&1
echo "###############################
Firewall configured.
###############################"

##############################
# change selinux to permissive
##############################
setenforce 0
echo "###############################
SElinux changed to permissive.
###############################"

##############################
# enable services.
##############################
services="dhcpd xinetd httpd"
for service in $services
do
	systemctl start $service > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		echo "Failed to start service: $service"
	else
		systemctl enable $service > /dev/null 2>&1
		echo "Services $service running and enabled."
	fi
done

##############################
# tell user basic pxe server is ready
##############################
echo "###############################
Basic PXE Server is Ready to use.
###############################"
