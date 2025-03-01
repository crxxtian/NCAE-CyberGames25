#!/bin/bash

# Prompt user for required inputs
read -p "Team Number: " team
read -p "Host Name: " name
read -p "IP Address: " ip
read -p "How many times have you run this (Serial Number): " serial

# Backup existing BIND configuration
cp -rp /etc/named /root/named_backup.d

# Ensure the zones directory exists
if [ ! -d /etc/named/zones ]; then
    mkdir -p /etc/named/zones
fi

# Copy template files for zones
cp /var/named/named.empty /etc/named/zones/forward.ncaecybergames.org
cp /var/named/named.empty /etc/named/zones/reverse.ncaecybergames.org
cp /var/named/named.empty /etc/named/zones/forward.team.net
cp /var/named/named.empty /etc/named/zones/reverse.team.net

# Configure named.conf.local with zone definitions
cat << EOF > /etc/named/named.conf.local
zone "team$team.ncaecybergames.org" IN {
    type master;
    file "/etc/named/zones/forward.ncaecybergames.org";
};

zone "18.172.in-addr.arpa" IN {
    type master;
    file "/etc/named/zones/reverse.ncaecybergames.org";
};

zone "team$team.net" IN {
    type master;
    file "/etc/named/zones/forward.team.net";
};

zone "$team.168.192.in-addr.arpa" IN {
    type master;
    file "/etc/named/zones/reverse.team.net";
};
EOF

# Configure Forward Zone for ncaecybergames.org
cat << EOF > /etc/named/zones/forward.ncaecybergames.org
\$TTL    86400
@       IN      SOA     team$team.ncaecybergames.org. root.(
                          $serial         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                          86400 )       ; Negative Cache TTL
;
@       IN      NS      $name
$name   IN      A       $ip
ns1     IN      A       172.18.13.$team
www     IN      A       172.18.13.$team
files   IN      A       172.18.14.$team
shell   IN      A       172.18.14.$team
EOF

# Configure Reverse Zone for ncaecybergames.org
cat << EOF > /etc/named/zones/reverse.ncaecybergames.org
\$TTL    86400
@       IN      SOA     team$team.ncaecybergames.org. root.team$team.ncaecybergames.org.(
                          $serial         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                          86400 )       ; Negative Cache TTL
;
@       IN      NS      $name.
$team.13        IN      PTR     ns1.team$team.ncaecybergames.org.
$team.13        IN      PTR     www.team$team.ncaecybergames.org.
$team.14        IN      PTR     files.team$team.ncaecybergames.org.
$team.14        IN      PTR     shell.team$team.ncaecybergames.org.
EOF

# Configure Forward Zone for team.net
cat << EOF > /etc/named/zones/forward.team.net
\$TTL    86400
@       IN      SOA     team$team.net. root.(
                          $serial         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                          86400 )       ; Negative Cache TTL
;
@       IN      NS      $name
$name   IN      A       $ip
ns1     IN      A       192.168.$team.12
www     IN      A       192.168.$team.5
db1     IN      A       192.168.$team.7
EOF

# Configure Reverse Zone for team.net
cat << EOF > /etc/named/zones/reverse.team.net
\$TTL    86400
@       IN      SOA     team$team.net. root.team$team.net.(
                          $serial         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                          86400 )       ; Negative Cache TTL
;
@       IN      NS      $name.
12      IN      PTR     ns1.team$team.net.
7       IN      PTR     db1.team$team.net.
5       IN      PTR     www.team$team.net.
EOF

# Restart BIND service and verify status
systemctl restart named
systemctl status named --no-pager
