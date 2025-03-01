#!/bin/bash

# Prompt user for input
read -p "Team Number: " team
read -p "Host Name: " name
read -p "IP Address: " ip

# Set paths for zone files
FORWARD_ZONE_FILE="/var/named/zones/forward.ncaecybergames.org"
REVERSE_ZONE_FILE="/var/named/zones/reverse.ncaecybergames.org"
FORWARD_TEAM_ZONE="/var/named/zones/forward.team.net"
REVERSE_TEAM_ZONE="/var/named/zones/reverse.team.net"

# Determine the current serial number
if [ -f "$FORWARD_ZONE_FILE" ]; then
    SERIAL=$(grep -oP '\d{10}' "$FORWARD_ZONE_FILE" | head -1)
    if [[ -z "$SERIAL" ]]; then
        SERIAL=$(date +%Y%m%d00)
    else
        SERIAL=$((SERIAL + 1))
    fi
else
    SERIAL=$(date +%Y%m%d00)
fi

echo "Using Serial Number: $SERIAL"

# Backup existing BIND configuration
cp -rp /var/named /root/named_backup.d

# Ensure the zones directory exists
if [ ! -d /var/named/zones ]; then
    mkdir -p /var/named/zones
    chown named:named /var/named/zones
    chmod 750 /var/named/zones
fi

# Apply SELinux context for BIND
semanage fcontext -a -t named_zone_t "/var/named/zones(/.*)?"
restorecon -R /var/named/zones

# Copy default empty zone files only if they don't exist
[[ ! -f "$FORWARD_ZONE_FILE" ]] && cp /var/named/named.empty "$FORWARD_ZONE_FILE"
[[ ! -f "$REVERSE_ZONE_FILE" ]] && cp /var/named/named.empty "$REVERSE_ZONE_FILE"
[[ ! -f "$FORWARD_TEAM_ZONE" ]] && cp /var/named/named.empty "$FORWARD_TEAM_ZONE"
[[ ! -f "$REVERSE_TEAM_ZONE" ]] && cp /var/named/named.empty "$REVERSE_TEAM_ZONE"

# Configure named.conf with security enhancements
cat << EOF > /etc/named.conf
options {
    directory "/var/named";

    allow-update { none; };

    allow-query { 192.168.6.0/24; 172.18.0.0/16; localhost; };

    allow-recursion { 192.168.6.0/24; 172.18.0.0/16; localhost; };

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

# Configure Forward Zone for External DNS (teamX.ncaecybergames.org)
cat << EOF > "$FORWARD_ZONE_FILE"
\$TTL    86400
@       IN      SOA     team$team.ncaecybergames.org. root.(
                          $SERIAL         ; Serial
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

# Configure Reverse Zone for External DNS
cat << EOF > "$REVERSE_ZONE_FILE"
\$TTL    86400
@       IN      SOA     team$team.ncaecybergames.org. root.team$team.ncaecybergames.org.(
                          $SERIAL         ; Serial
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

# Configure Forward Zone for Internal DNS (teamX.net)
cat << EOF > "$FORWARD_TEAM_ZONE"
\$TTL    86400
@       IN      SOA     team$team.net. root.(
                          $SERIAL         ; Serial
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

# Configure Reverse Zone for Internal DNS
cat << EOF > "$REVERSE_TEAM_ZONE"
\$TTL    86400
@       IN      SOA     team$team.net. root.team$team.net.(
                          $SERIAL         ; Serial
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

# Restart BIND only if changes were made
if ! systemctl is-active --quiet named; then
    echo "Restarting named service..."
    systemctl restart named
else
    echo "No restart needed. DNS is already running correctly."
fi

# Verify service status
echo "Verifying BIND DNS service..."
systemctl status named --no-pager

# Test DNS resolution
echo "Testing DNS queries..."
DNS_SERVER="192.168.$team.12"

nslookup www.team$team.net $DNS_SERVER
nslookup db1.team$team.net $DNS_SERVER
nslookup www.team$team.ncaecybergames.org 172.18.13.$team

nslookup 192.168.$team.5 $DNS_SERVER
nslookup 172.18.13.$team 172.18.13.$team

echo "DNS verification completed."
