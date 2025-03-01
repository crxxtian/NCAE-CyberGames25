#!/bin/bash

# Prompt user for input
read -p "Team Number: " team
read -p "Host Name: " name
read -p "IP Address: " ip

# Set paths for zone files
FORWARD_EXTERNAL="/var/named/zones/forward.ncaecybergames.org"
REVERSE_EXTERNAL="/var/named/zones/reverse.ncaecybergames.org"
FORWARD_INTERNAL="/var/named/zones/forward.team.net"
REVERSE_INTERNAL="/var/named/zones/reverse.team.net"

# Determine the current serial number
if [ -f "$FORWARD_EXTERNAL" ]; then
    SERIAL=$(grep -oP '\d{10}' "$FORWARD_EXTERNAL" | head -1)
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

# Check if SELinux is enabled before applying context
if [[ $(getenforce) == "Enforcing" || $(getenforce) == "Permissive" ]]; then
    echo "Applying SELinux context for BIND..."
    semanage fcontext -a -t named_zone_t "/var/named/zones(/.*)?"
    restorecon -R /var/named/zones
else
    echo "SELinux is disabled. Skipping SELinux adjustments."
fi

# Configure named.conf with full security settings
cat << EOF > /etc/named.conf
options {
    directory "/var/named";

    allow-update { none; };

    allow-query { 192.168.6.0/24; 172.18.0.0/16; localhost; };

    allow-recursion { 192.168.6.0/24; 172.18.0.0/16; localhost; };

    dnssec-enable yes;
    dnssec-validation auto;
    dnssec-lookaside auto;
    managed-keys-directory "/var/named/dynamic";
    dnssec-must-be-secure "team$team.net" yes;

    rate-limit {
        responses-per-second 10;
        window 5;
    };

    allow-transfer { none; };

    minimal-responses yes;

    logging {
        channel security_log {
            file "/var/log/named/security.log" versions 3 size 5m;
            severity dynamic;
            print-time yes;
        };
        category security { security_log; };
    };

    response-policy { zone "rpz.blocked-domains"; } recursive-only no;
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

# Configure Forward Zone for External DNS
cat << EOF > "$FORWARD_EXTERNAL"
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
cat << EOF > "$REVERSE_EXTERNAL"
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

# Configure Forward Zone for Internal DNS
cat << EOF > "$FORWARD_INTERNAL"
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
cat << EOF > "$REVERSE_INTERNAL"
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

# Restart and verify BIND service
systemctl restart named
systemctl status named --no-pager

# Apply firewall rules to block external DNS poisoning attempts
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source not address="192.168.6.0/24" drop'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source not address="172.18.0.0/16" drop'
firewall-cmd --reload

# Verify DNSSEC
dig DNSKEY team$team.net +dnssec | grep -q "RRSIG" && echo "DNSSEC is enabled." || echo "DNSSEC validation failed."

# Verify DNS functionality
nslookup www.team$team.net 192.168.$team.12
nslookup db1.team$team.net 192.168.$team.12
nslookup www.team$team.ncaecybergames.org 172.18.13.$team
