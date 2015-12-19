#!/bin/bash

# Script Name: sssd-ad-config.sh
#
# Author: Mark Rodgers
# Version: 1.0
# Last Modified by: Mark Rodgers
# Last modified date: December 12, 2015
#
# Description:
#  This script installs the necessary applications and makes the
#  necessary configurations to enable SSSD and connect the machine
#  to the domain
#
# Parameters:
#  1 - ip1: The IP address of the first domain server
#  2 - name1: The machine name of the first domain server
#  3 - ip2: The IP address of the second domain server
#  4 - name2: The machine name of the second domain server
#  5 - domain: The Active Directory domain name
#  6 - sssd username to use to add the machine to AD
#  7 - sssd password to use to add the machine to AD
#
# Example:
#  adscript.sh 10.2.4.135 hdpmarkad0 10.2.4.136 hdpmarkad1 ad.example.com sssd_user sssd_pass
#  adscript.sh 172.29.84.135 hdpqaad0 172.29.84.136 hdpqaad1 hdpqa.honeywell.com sssd_user sssd_pass

echo '## Running disk setup'
bash centos-vm-disk-utils.sh -b /datadisks

# Install required elements
echo "## Installing required elements"
yum install -y realmd sssd samba samba-common oddjob oddjob-mkhomedir adcli krb5-workstation

# Add the AD IP adddresses to the hosts file
cp /etc/hosts /tmp/hosts.backup
echo "## Backed up /etc/hosts to /temp/hosts.backup"
echo "## Adding IP addresses $1 and $3 to the hosts file"
echo $1 $2.$5 $2 >> /etc/hosts
echo $3 $4.$5 $4 >> /etc/hosts

# Turn off PeerDns
echo "## Turning off PeerDNS"
sed -i -e 's@^PEERDNS=yes@PEERDNS=no@' /etc/sysconfig/network-scripts/ifcfg-eth0

# Turn off and disable NetworkManager service
echo "## Stopping and disabling Network Manager service"
systemctl stop NetworkManager.service
systemctl disable NetworkManager.service

# Add servers to resolv.conf
new_resolv="/tmp/resolv.conf.new"
backup_resolv="/tmp/resolv.conf.backup"

cp /etc/resolv.conf $backup_resolv
echo "## Backed up /etc/resolv.conf to $backup_resolv"
echo "## Creating new resolv.conf at $new_resolv"
echo ';file generated by honeywell connected analytics ad setup' > $new_resolv
echo 'domain' $5 >> $new_resolv
echo 'search' $2.$5 >> $new_resolv
echo 'search' $4.$5 >> $new_resolv
echo 'nameserver' $1 >> $new_resolv
echo 'nameserver' $3 >> $new_resolv
echo 'nameserver 168.63.129.16' >> $new_resolv

echo "## Replacing /etc/resolv.conf with $new_resolv"
yes | cp -rf $new_resolv /etc/resolv.conf

echo 'HOSTNAME='$HOSTNAME'.'$5 >> /etc/sysconfig/network

echo 'net.ipv6.conf.all.disable_ipv6 = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.default.disable_ipv6 = 1' >> /etc/sysctl.conf
echo 'net/ipv6.conf.lo.disable_ipv6 = 1' >> /etc/sysctl.conf
echo 'vm.swappiness=0' >> /etc/sysctl.conf

sed -i -e 's@^SELINUX=enforcing@SELINUX=disabled@' /etc/selinux/config

echo 'if test -f /sys/kernel/mm/redhat_transparent_hugepage/defrag; then echo never > /sys/kernel/mm/redhat_transparent_hugepage/defrag; fi' >> /etc/rc.local

echo 'if test -f /sys/kernel/mm/redhat_transparent_hugepage/enabled; then echo never > /sys/kernel/mm/redhat_transparent_hugepage/enabled; fi' >> /etc/rc.local

sed -i -e 's@umask 002$@umask 0027@' /etc/profile
sed -i -e 's@umask 022$@umask 0027@' /etc/profile

# Add the server to the domain
echo "## Adding the server to the domain"
kinit -kt sv-qa_sssd_bind.keytab sv-qa_sssd_bind@HDPQA.HONEYWELL.COM
realm join HDPQA.HONEYWELL.COM
#realm join --user=$6@$5 $5

echo '##Removing the keytab file'
rm sv-qa_sssd_bind.keytab

sed -i -e 's@^use_fully_qualified_names = True@use_fully_qualified_names = False@' /etc/sssd/sssd.conf
echo 'enumerate = True' >> /etc/sssd/sssd/conf

echo '## Restarting sssd'
service sssd restart

echo '## COMPLETE ##'