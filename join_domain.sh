#!/bin/bash

. ./env_vars.sh
. ./functions.sh

if [[ `tty` != "/dev/tty1" ]]
then
    echo "Run this from the console, not ssh"
    exit 1
fi

if [[ `hostname` = "localhost.localdomain" ]]
then
    echo Must set hostname in /etc/hostname
    exit 1
fi

IP=`hostname -I`
echo $IP | grep -q " "
if [[ $? != 1 ]]
then
    echo "Multiple interfaces on this host.  Set IP manually"
    exit 1
fi

if [[ "$IP" = "$DNS1" ]]
then
    echo "Joining the DC to itself breaks things."
    echo "Export the keytab by hand using instructions in https://wiki.samba.org/index.php/Local_user_management_and_authentication/sssd"
    echo "Which is in the script domain_controller_local_authentication.sh"
    exit 1
fi

DATETIME=`date +%Y%m%d_%H%M%S`

echo "Installing NTP..."
yum install -y ntpdate ntp
ntpdate clock.redhat.com
enableService ntpd
startService  ntpd

echo "Installing adcli..."
yum -y install adcli

echo "Joining domain..."
adcli -v join $DOMAIN

echo "Setting up kerberos client tools..."
yum -y install krb5-workstation

cp -p /etc/krb5.conf /etc/krb5.conf.$DATETIME
cat <<EOF > /etc/krb5.conf
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 dns_lookup_realm = true
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
 default_realm = $REALM
EOF

echo "Installing sssd etc..."
yum -y install sssd authconfig oddjob

echo "Configuring sssd etc..."
authconfig --enablesssd --enablesssdauth --enablemkhomedir --update

cat <<EOF > /etc/sssd/sssd.conf
[sssd]
config_file_version = 2
services = nss, pam, ssh
domains = $DOMAIN

[domain/$DOMAIN]
id_provider = ad
enumerate=true
dyndns_update=true
ldap_schema = rfc2307bis
ldap_id_mapping = false

EOF
chmod 0600 /etc/sssd/sssd.conf

rm -f /var/lib/sss/db/* /var/lib/sss/mc/*

enableService sssd
startService  sssd
