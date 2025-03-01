#!/bin/bash

# Prompt user for input
read -p "Team Number: " team
read -p "Host Name: " name
read -p "IP Address: " ip

# Set the path for the forward zone file
FORWARD_ZONE_FILE="/var/named/zones/forward.ncaecybergames.org"

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

# Only update zone files if they are incorrect
if ! grep -q "$name" "$FORWARD_ZONE_FILE" || ! grep -q "$ip" "$FORWARD_ZONE_FILE"; then
    echo "⚠ Incorrect or outdated DNS records detected. Updating..."
    cp /var/named/named.empty "$FORWARD_ZONE_FILE"
    cp /var/named/named.empty /var/named/zones/reverse.ncaecybergames.org
    cp /var/named/named.empty /var/named/zones/forward.team.net
    cp /var/named/named.empty /var/named/zones/reverse.team.net
else
    echo "✅ DNS records are already correct. No changes needed."
fi

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

# Set correct ownership and permissions
chown -R named:named /var/named/zones
chmod -R 640 /var/named/zones

# Restart BIND only if changes were made
if ! systemctl is-active --quiet named; then
    echo "Restarting named service..."
    systemctl restart named
else
    echo "✅ No restart needed. DNS is already running correctly."
fi

# Verify service status
echo "Verifying BIND DNS service..."
systemctl status named --no-pager

# Verification: Test DNS resolution
echo "Testing DNS queries..."
DNS_SERVER="192.168.$team.12"

# Test forward lookups
nslookup www.team$team.net $DNS_SERVER
nslookup db1.team$team.net $DNS_SERVER
nslookup www.team$team.ncaecybergames.org 172.18.13.$team

# Test reverse lookups
nslookup 192.168.$team.5 $DNS_SERVER
nslookup 172.18.13.$team 172.18.13.$team

# Display summary
if systemctl is-active --quiet named; then
    echo "✅ BIND is running."
else
    echo "❌ ERROR: BIND is NOT running!"
fi

echo "✅ DNS verification completed."
echo "To manually test, use: nslookup www.team$team.net $DNS_SERVER"
