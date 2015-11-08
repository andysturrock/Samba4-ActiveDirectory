#!/bin/bash

# The name of the Active Directory domain
DOMAIN=ad.example.com

# First part of domain - eg "ad"
SHORTDOMAIN=`echo $DOMAIN | cut -f1 -d"."`

# For Kerberos.  Same as AD domain but in upper case.
REALM=`echo $DOMAIN | tr [a-z] [A-Z]`

# The IP address of the primary domain controller.
# Called DNS1 as that's what is used in all the
# network config scrips.
DNS1=192.168.0.1

# Administrator account which has join domain permissions
Administrator=Administrator
