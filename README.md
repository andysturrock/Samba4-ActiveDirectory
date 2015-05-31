# Samba4-ActiveDirectory
Scripts and code for Active Directory integration

Scripts and their purpose
=========================
env_vars.sh
-----------
Set the variable values for the rest of the scripts.

functions.sh
------------
Functions for starting and stopping services using either
classic init style script commands or systemd equivalents.

setup_network.sh
----------------
Sets up the network config on a domain controller or member box.
Run this before any of the other scripts.

setup_samba.sh
--------------
Build, install and configure Samba4 as an Active Directory Domain Controller.
Note this script assumes you are running on a 192.168.0.x addressed LAN.

domain_controller_local_authentication.sh
-----------------------------------------
Run this on the domain controller to enable network logins on that box itself.

join_domain.sh
--------------
Run this on a domain member box to join it to the domain and enable network logins.

Notes
=====
This setup has been tested with a Centos 6.6 domain controller and
Fedora 21 and Centos 6.6 domain members.
