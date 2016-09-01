#!/usr/bin/bash
# @Author: Aldo Sotolongo
# @Date:   2016-08-29T23:38:02-04:00
# @Email:  aldenso@gmail.com
# @Last modified by:   Aldo Sotolongo
# @Last modified time: 2016-09-01T14:44:56-04:00
# FILE: pxe_configure.sh
# DESCRIPTION: Script to automate a basic centos7 pxe
# REQUIREMENTS: centos7 OS, centos install image in $IMAGEDIR dir.

##############################
# Configuration
##############################
TFTPDIR="/var/lib/tftpboot"
IMAGEDIR="/var/www/html/centos7"
IMAGEPXE="$IMAGEDIR/images/pxeboot"
DHCPDIR="/etc/dhcp"
TFTPCONF="/etc/xinetd.d"
DHCPSERVER="192.168.100.1"
DHCPSUBNETMASK="255.255.255.0"
DHCPSUBNET=$(ipcalc -n $DHCPSERVER $DHCPSUBNETMASK | cut -d "=" -f2)
DHCPBROADCAST=$(ipcalc -b $DHCPSERVER $DHCPSUBNETMASK | cut -d "=" -f2)
DHCPRANGEFIRSTIP="192.168.100.150"
DHCPRANGELASTIP="192.168.100.200"
SYSLINUXDIR="/usr/share/syslinux"


if ( [ -d "$IMAGEDIR" ] && [ -d "$IMAGEPXE" ] )
then
	echo "$IMAGEDIR and $IMAGEPXE exist"
else
	echo "Make sure IMAGEDIR and IMAGEPXE exist and are properly configured.
IMAGEDIR: $IMAGEDIR
IMAGEPXE: $IMAGEPXE
"
	exit 1
fi

##############################
# Install packages.
##############################
packages="dhcp syslinux tftp-server httpd xinetd"
yum install -y $packages > /dev/null 2>&1
if [ $? -eq 0 ]
then
	echo "Packages $packages installed successfully"
else
	echo "Failed to install Packages."
	exit 1
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
sed -i s/"subnet 192.168.100.0 netmask 255.255.255.0"/"subnet $DHCPSUBNET netmask $DHCPSUBNETMASK"/g dhcpd.conf-template
sed -i s/"range 192.168.100.231 192.168.100.253;"/"range $DHCPRANGEFIRSTIP $DHCPRANGELASTIP;"/g dhcpd.conf-template
sed -i s/"option routers 192.168.100.1;"/"option routers $DHCPSERVER;"/g dhcpd.conf-template
sed -i s/"next-server 192.168.100.1;"/"next-server $DHCPSERVER;"/g dhcpd.conf-template
sed -i s/"option broadcast-address 192.168.100.254;"/"option broadcast-address $DHCPBROADCAST;"/g dhcpd.conf-template
mv dhcpd.conf-template dhcpd.conf-template-final
mv dhcpd.conf-template-orig dhcpd.conf-template
cp dhcpd.conf-template-final $DHCPDIR/dhcpd.conf
echo "###############################
DHCP configured.
DHCP IP: $DHCPSERVER
DHCP MASK: $DHCPSUBNETMASK
DHCP BROADCAST: $DHCPBROADCAST
DHCP RANGE: $DHCPRANGEFIRSTIP - $DHCPRANGELASTIP
###############################"

##############################
# update syslinux menu
##############################
sed -e "s|inst.repo=http://192.168.100.1|inst.repo=http://$DHCPSERVER|g" default_menu > default_menu-final

##############################
# copy syslinux templates
##############################
cp $SYSLINUXDIR/menu.c32 $SYSLINUXDIR/pxelinux.0 $SYSLINUXDIR/memdisk $SYSLINUXDIR/mboot.c32 $SYSLINUXDIR/chain.c32 $TFTPDIR
cp $IMAGEPXE/vmlinuz $IMAGEPXE/initrd.img $TFTPDIR
mkdir $TFTPDIR/pxelinux.cfg
cp default_menu-final $TFTPDIR/pxelinux.cfg/default
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
$(firewall-cmd --list-services --zone=public --permanent)
###############################"

##############################
# change selinux to permissive
##############################
setenforce 0
sed -i s/"^SELINUX=enforcing"/"SELINUX=permissive"/g /etc/selinux/config
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
