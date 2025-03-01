#!/bin/bash

# Prompt user for input
read -p "Team Number: " team
read -p "Host Name: " name
read -p "IP Address: " ip
read -p "How many times have you run this (Serial Number): " serial

# Backup existing BIND configuration
cp -rp /var/named /root/named_backup.d

# Ensure the zones directory exists
if [ ! -d /var/named/zones ]; then
    mkdir -p /var/named/zones
    chown named:named /var/named/zones
    chmod 750 /var/named/zones
fi

# Apply SELinux context for BIND to read `/var/named/zones/`
semanage fcontext -a -t named_zone_t "/var/named/zones(/.*)?"
restorecon -R /var/named/zones

# Copy default empty zone files
cp /var/named/named.empty /var/named/zones/forward.ncaecybergames.org
cp /var/named/named.empty /var/named/zones/reverse.ncaecybergames.org
cp /var/named/named.empty /var/named/zones/forward.team.net
cp /var/named/named.empty /var/named/zones/reverse.team.net

# Configure named.conf with security enhancements
cat << EOF > /etc/named.conf
options {
    directory "/var/named";

    // Prevent unauthorized zone updates
    allow-update { none; };

    // Allow DNS queries only from trusted networks
    allow-query { 192.168.6.0/24; 172.18.0.0/16; localhost; };

    // Allow recursion for internal users only (Prevents open DNS resolver abuse)
    allow-recursion { 192.168.6.0/24; 172.18.0.0/16; localhost; };

    // Other security settings
    dnssec-enable yes;
    dnssec-validation yes;
};

zone "team$team.ncaecybergames.org" IN {
    type master;
    file "/var/named/zones/forward.ncaecybergames.org";
};

zone "18.172.in-addr.arpa" IN {
    type master;
    file "/var/named/zones/reverse.ncaecybergames.org";
};

zone "team$team.net" IN {
    type master;
    file "/var/named/zones/forward.team.net";
};

zone "$team.168.192.in-addr.arpa" IN {
    type master;
    file "/var/named/zones/reverse.team.net";
};
EOF

# Configure Forward Zone for ncaecybergames.org
cat << EOF > /var/named/zones/forward.ncaecybergames.org
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
cat << EOF > /var/named/zones/reverse.ncaecybergames.org
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
cat << EOF > /var/named/zones/forward.team.net
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
cat << EOF > /var/named/zones/reverse.team.net
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

# Set correct ownership and permissions
chown -R named:named /var/named/zones
chmod -R 640 /var/named/zones

# Restart BIND service and verify status
systemctl restart named
systemctl status named --no-pager
