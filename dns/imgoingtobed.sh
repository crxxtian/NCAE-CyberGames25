#!/bin/bash

echo "Setting up Secure DNS for Competition (Rocky 8)..."

# Check if required packages are installed
REQUIRED_PKGS=("bind" "bind-utils" "policycoreutils-python-utils" "firewalld" "net-tools" "nano")
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! rpm -q $pkg &>/dev/null; then
        echo "Installing missing package: $pkg"
        dnf install -y $pkg
    else
        echo "$pkg is already installed."
    fi
done

# Enable and start required services
systemctl enable --now named
systemctl enable --now firewalld

# Get user input for configuration
read -p "Team Number: " team
read -p "Host Name: " name
read -p "IP Address: " ip
read -p "How many times have you run this (Serial Number): " serial

# Set paths for zone files
ZONES_DIR="/var/named/zones"
FORWARD_EXTERNAL="$ZONES_DIR/forward.ncaecybergames.org"
REVERSE_EXTERNAL="$ZONES_DIR/reverse.ncaecybergames.org"
FORWARD_INTERNAL="$ZONES_DIR/forward.team.net"
REVERSE_INTERNAL="$ZONES_DIR/reverse.team.net"

# Ensure the zones directory exists with correct permissions
if [ ! -d "$ZONES_DIR" ]; then
    mkdir -p "$ZONES_DIR"
    chown named:named "$ZONES_DIR"
    chmod 750 "$ZONES_DIR"
fi

# Check if SELinux is installed and enabled before applying context
if command -v getenforce &>/dev/null && [[ "$(getenforce)" != "Disabled" ]]; then
    echo "SELinux is enabled. Applying context for BIND..."
    semanage fcontext -a -t named_zone_t "$ZONES_DIR(/.*)?"
    restorecon -R "$ZONES_DIR"
else
    echo "SELinux is not installed or is disabled. Skipping SELinux context adjustments."
fi

# Secure `named.conf`
cat << EOF > /etc/named.conf
options {
    directory "/var/named";

    allow-update { none; };
    allow-query { any; };
    allow-recursion { 192.168.$team.0/24; 172.18.0.0/16; localhost; };

    dnssec-enable yes;
    dnssec-validation yes;
    managed-keys-directory "/var/named/dynamic";

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
};

zone "team$team.ncaecybergames.org" IN {
    type master;
    file "$FORWARD_EXTERNAL";
};

zone "13.18.172.in-addr.arpa" IN {
    type master;
    file "$REVERSE_EXTERNAL";
};

zone "team$team.net" IN {
    type master;
    file "$FORWARD_INTERNAL";
};

zone "$team.168.192.in-addr.arpa" IN {
    type master;
    file "$REVERSE_INTERNAL";
};
EOF

# Configure Forward Zone for External DNS
cat << EOF > "$FORWARD_EXTERNAL"
\$TTL 86400
@   IN  SOA  ns1.team$team.ncaecybergames.org. root.(
        $serial
        604800
        86400
        2419200
        86400 )
;
@       IN  NS  ns1.team$team.ncaecybergames.org.
ns1     IN  A   172.18.13.$team
www     IN  A   172.18.13.$team
shell   IN  A   172.18.14.$team
files   IN  A   172.18.14.$team
EOF

# Configure Reverse Zone for External DNS
cat << EOF > "$REVERSE_EXTERNAL"
\$TTL 86400
@   IN  SOA  ns1.team$team.ncaecybergames.org. root.team$team.ncaecybergames.org. (
        $serial
        604800
        86400
        2419200
        86400 )
;
@       IN  NS  ns1.team$team.ncaecybergames.org.
$team.13  IN  PTR ns1.team$team.ncaecybergames.org.
$team.13  IN  PTR www.team$team.ncaecybergames.org.
$team.14  IN  PTR shell.team$team.ncaecybergames.org.
$team.14  IN  PTR files.team$team.ncaecybergames.org.
EOF

# Configure Forward Zone for Internal DNS
cat << EOF > "$FORWARD_INTERNAL"
\$TTL 86400
@   IN  SOA  ns1.team$team.net. root.(
        $serial
        604800
        86400
        2419200
        86400 )
;
@       IN  NS  ns1.team$team.net.
ns1     IN  A   192.168.$team.12
www     IN  A   192.168.$team.5
db      IN  A   192.168.$team.7
EOF

# Configure Reverse Zone for Internal DNS
cat << EOF > "$REVERSE_INTERNAL"
\$TTL 86400
@   IN  SOA  ns1.team$team.net. root.team$team.net. (
        $serial
        604800
        86400
        2419200
        86400 )
;
@       IN  NS  ns1.team$team.net.
12      IN  PTR ns1.team$team.net.
5       IN  PTR www.team$team.net.
7       IN  PTR db.team$team.net.
EOF

# Set correct ownership and permissions
chown -R named:named "$ZONES_DIR"
chmod -R 640 "$ZONES_DIR"

# Validate BIND configuration before restart
named-checkconf && echo "BIND configuration syntax is valid." || { echo "ERROR in named.conf!"; exit 1; }
named-checkzone team$team.ncaecybergames.org "$FORWARD_EXTERNAL"
named-checkzone team$team.net "$FORWARD_INTERNAL"

# Restart BIND service and verify status
systemctl restart named
systemctl status named --no-pager

# Verify DNS resolution
nslookup www.team$team.net 192.168.$team.12
nslookup www.team$team.ncaecybergames.org 172.18.13.$team
