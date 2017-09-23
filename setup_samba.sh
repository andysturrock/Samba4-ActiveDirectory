#install all pre-reqs
yum -y install gcc libacl-devel libblkid-devel gnutls-devel \
   readline-devel python-devel gdb pkgconfig krb5-workstation \
   zlib-devel setroubleshoot-server libaio-devel \
   setroubleshoot-plugins policycoreutils-python \
   libsemanage-python setools-libs-python setools-libs \
   popt-devel libpcap-devel sqlite-devel libidn-devel \
   libxml2-devel libacl-devel libsepol-devel libattr-devel \
   keyutils-libs-devel cyrus-sasl-devel cups-devel bind-utils \
   docbook-style-xsl libxslt perl gamin-devel openldap-devel \
   pam-devel perl-Parse-Yapp xfsprogs-devel NetworkManager

# configure
./configure --enable-debug --enable-selftest
make
su -c "make install"

. ./functions.sh

. ./env_vars.sh

echo "Temporarily using google DNS..."
cat <<EOF > /etc/resolv.conf
nameserver 8.8.8.8
EOF

echo "Installing NTP..."
yum install -y ntpdate ntp
ntpdate clock.redhat.com
enableService ntpd
startService  ntpd

DATETIME=`date +%Y%m%d_%H%M%S`

echo "Provisioning $DOMAIN..."
rm -rf /usr/local/samba/etc/smb.conf
rm -rf /usr/local/samba/private/*
/usr/local/samba/bin/samba-tool domain provision --use-rfc2307 --dns-backend=BIND9_DLZ --realm=$DOMAIN --domain=$SHORTDOMAIN --adminpass=ChangeMe1 --server-role=dc

yum -y install bind
rndc-confgen -a -r /dev/urandom

cat <<EOF > /var/named/forwarders.conf
forwarders { 8.8.8.8; 8.8.4.4; } ;
EOF

IP=`hostname -I`
echo $IP | grep -q " "
if [[ $? != 1 ]]
then
    echo "Multiple interfaces on this host.  Set IP manually"
    exit 1
fi

cp -p /etc/named.conf /etc/named.conf.$DATETIME
cat <<EOF > /etc/named.conf
options {
        listen-on port 53 { 127.0.0.1; $IP; };
//        listen-on-v6 port 53 { any; };

        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        allow-query     { localnets; };
        recursion yes;

        dnssec-enable no;
        dnssec-validation no;
//        dnssec-enable yes;
//        dnssec-validation yes;
//        dnssec-lookaside auto;

        /* Path to ISC DLV key */
        bindkeys-file "/etc/named.iscdlv.key";

        managed-keys-directory "/var/named/dynamic";

        tkey-gssapi-keytab "/usr/local/samba/private/dns.keytab";

        include "forwarders.conf";

};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "." IN {
        type hint;
        file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
include "/usr/local/samba/private/named.conf";
include "/etc/rndc.key";

EOF

mv /etc/krb5.conf /etc/krb5.conf.$DATETIME
cp /usr/local/samba/private/krb5.conf /etc/krb5.conf

cp -p /etc/sysconfig/named /etc/sysconfig/named.$DATETIME
echo OPTIONS="-4" >> /etc/sysconfig/named

echo "Setting SELinux contexts etc..."
chown -R named:named /usr/local/samba/private/dns
chown -R named:named /usr/local/samba/private/sam.ldb.d
chown named:named /usr/local/samba/private/dns.keytab
chown named:named /etc/rndc.key

chcon -t named_conf_t /usr/local/samba/private/dns.keytab
semanage fcontext -a -t named_conf_t /usr/local/samba/private/dns.keytab
chcon -t named_conf_t /usr/local/samba/private/named.conf
semanage fcontext -a -t named_conf_t /usr/local/samba/private/named.conf
chcon -t named_var_run_t /usr/local/samba/private/dns
semanage fcontext -a -t named_var_run_t /usr/local/samba/private/dns
chcon -t named_var_run_t /usr/local/samba/private/dns/sam.ldb
semanage fcontext -a -t named_var_run_t /usr/local/samba/private/dns/sam.ldb
chcon -t named_var_run_t /usr/local/samba/private/dns/sam.ldb.d
semanage fcontext -a -t named_var_run_t /usr/local/samba/private/dns/sam.ldb.d
for file in `ls /usr/local/samba/private/dns/sam.ldb.d`
do
    chcon -t named_var_run_t /usr/local/samba/private/dns/sam.ldb.d/$file
    semanage fcontext -a -t named_var_run_t /usr/local/samba/private/dns/sam.ldb.d/$file
done
for file in `ls /usr/local/samba/private/sam.ldb.d`
do
    chcon -t named_var_run_t /usr/local/samba/private/sam.ldb.d/$file
    semanage fcontext -a -t named_var_run_t /usr/local/samba/private/sam.ldb.d/$file
done
restorecon -vR /usr/local/samba/

echo "Setting firewall rules..."
iptables -I INPUT -s 192.168.0.0/24 -p tcp --dport 53 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p udp --dport 53 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p tcp --dport 88 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p udp --dport 88 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p tcp --dport 135 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p tcp --dport 137 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p tcp --dport 138 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p tcp --dport 139 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p tcp --dport 389 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p udp --dport 389 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p tcp --dport 445 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p tcp --dport 464 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p udp --dport 464 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p tcp --dport 636 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p tcp --dport 1024:1032 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p tcp --dport 3268 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p tcp --dport 3269 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p tcp --dport 5353 -j ACCEPT
iptables -I INPUT -s 192.168.0.0/24 -p udp --dport 5353 -j ACCEPT

service iptables save

echo "Starting DNS..."
enableService named
startService named

# Switching to internal DNS...
cat <<EOF > /etc/resolv.conf
nameserver $DNS1
search $DOMAIN
EOF

cat <<EOF > /etc/init.d/samba4
#!/bin/bash
#
# samba4        This shell script takes care of starting and stopping
#               samba4 daemons.
#
# chkconfig: - 58 74
# description: Samba 4 acts as an Active Directory Domain Controller.

### BEGIN INIT INFO
# Provides: samba4
# Required-Start: \$network \$local_fs \$remote_fs
# Required-Stop: \$network \$local_fs \$remote_fs
# Should-Start: \$syslog \$named
# Should-Stop: \$syslog \$named
# Short-Description: start and stop samba4
# Description: Samba 4 acts as an Active Directory Domain Controller.
### END INIT INFO

# Source function library.
. /etc/init.d/functions


# Source networking configuration.
. /etc/sysconfig/network


prog=samba
prog_args="-d2 -l /var/log/ -D"
prog_dir=/usr/local/samba/sbin/
lockfile=/var/lock/subsys/\$prog


start() {
        [ "\$NETWORKING" = "no" ] && exit 1

        # Start daemons.
        echo -n $"Starting samba4: "
        daemon \$prog_dir/\$prog \$prog_args
        RETVAL=\$?
        echo
        [ \$RETVAL -eq 0 ] && touch \$lockfile
        return \$RETVAL
}


stop() {
        [ "\$EUID" != "0" ] && exit 4
        echo -n $"Shutting down samba4: "
        killproc \$prog_dir/\$prog
        RETVAL=\$?
        echo
        [ \$RETVAL -eq 0 ] && rm -f \$lockfile
        return \$RETVAL
}


# See how we were called.
case "\$1" in
start)
        start
        ;;
stop)
        stop
        ;;
status)
        status \$prog
        ;;
restart)
        stop
        start
        ;;
reload)
        echo "Not implemented yet."
        exit 3
        ;;
*)
        echo $"Usage: \$0 {start|stop|status|restart|reload}"
        exit 2
esac

EOF

chmod 555 /etc/init.d/samba4

echo "Starting samba..."
enableService samba4
startService samba4

# Run samba like this to test
#/usr/local/samba/sbin/samba -i -M single -d2

# Run named like this to test
#named -u named -4 -f -g -d2

echo "Disabling password complexity..."
/usr/local/samba/bin/samba-tool domain passwordsettings set --complexity=off
/usr/local/samba/bin/samba-tool domain passwordsettings set --history-length=0
/usr/local/samba/bin/samba-tool domain passwordsettings set --min-pwd-age=0
/usr/local/samba/bin/samba-tool domain passwordsettings set --max-pwd-age=0
/usr/local/samba/bin/samba-tool domain passwordsettings set --min-pwd-length=0

echo "Adding users..."
/usr/local/samba/bin/samba-tool user add user1 ChangeMe1 --must-change-at-next-login --surname=Surname --given-name=FirstName --uid=user1 --uid-number=10000 --gid-number=10000 --login-shell=/bin/bash
/usr/local/samba/bin/samba-tool user add user2 ChangeMe1 --must-change-at-next-login --surname=Surname --given-name=FirstName --uid=user2 --uid-number=10001 --gid-number=10000 --login-shell=/bin/bash

echo "Now manually set the group id and NIS domain using dsa.msc"
# Change passwords like this (on domain controller box)
#/usr/local/samba/bin/samba-tool user setpassword user1
