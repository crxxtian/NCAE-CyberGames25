#!/bin/bash

# Set fixed team number
TEAM_NUMBER=6

# Define domain names
INTERNAL_DOMAIN="team6.net"
EXTERNAL_DOMAIN="team6.ncaecybergames.org"

# Define static IP addresses
INTERNAL_NS_IP="192.168.$TEAM_NUMBER.12"
EXTERNAL_NS_IP="172.18.13.$TEAM_NUMBER"

# Define paths
ZONES_DIR="/var/named/zones"
NAMED_CONF="/etc/named.conf"
LOG_FILE="/var/log/dns_setup.log"

# Clear log file
sudo echo "DNS Setup Log - $(date)" > $LOG_FILE

# Check if BIND is installed
if ! command -v named > /dev/null; then
    echo "ERROR: BIND (named) is not installed. Installing now..." | tee -a $LOG_FILE
    sudo dnf install bind bind-utils -y
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to install BIND. Exiting." | tee -a $LOG_FILE
        exit 1
    fi
    echo "BIND installed successfully." | tee -a $LOG_FILE
fi

# Ensure the zones directory exists
if [ ! -d "$ZONES_DIR" ]; then
    sudo mkdir -p "$ZONES_DIR"
    sudo chown -R named:named "$ZONES_DIR"
    sudo chmod 750 "$ZONES_DIR"
    echo "Created zones directory at $ZONES_DIR" | tee -a $LOG_FILE
fi

# Define zone file paths
FORWARD_INTERNAL="$ZONES_DIR/forward.$INTERNAL_DOMAIN"
REVERSE_INTERNAL="$ZONES_DIR/reverse.$INTERNAL_DOMAIN"
FORWARD_EXTERNAL="$ZONES_DIR/external.forward.$EXTERNAL_DOMAIN"
REVERSE_EXTERNAL="$ZONES_DIR/external.reverse.$EXTERNAL_DOMAIN"

# Copy named.empty as a base template
sudo cp /var/named/named.empty "$FORWARD_INTERNAL"
sudo cp /var/named/named.empty "$REVERSE_INTERNAL"
sudo cp /var/named/named.empty "$FORWARD_EXTERNAL"
sudo cp /var/named/named.empty "$REVERSE_EXTERNAL"

# Internal Forward Lookup Zone
sudo bash -c "cat <<EOF > $FORWARD_INTERNAL
\$TTL 86400
@   IN  SOA  ns1.$INTERNAL_DOMAIN. admin.$INTERNAL_DOMAIN. (
        $(date +%Y%m%d%H)
        3600
        1800
        604800
        86400 )

@       IN  NS  ns1.$INTERNAL_DOMAIN.
ns1     IN  A   $INTERNAL_NS_IP
www     IN  A   192.168.6.5
db      IN  A   192.168.6.7
EOF"

# Internal Reverse Lookup Zone
sudo bash -c "cat <<EOF > $REVERSE_INTERNAL
\$TTL 86400
@   IN  SOA  ns1.$INTERNAL_DOMAIN. admin.$INTERNAL_DOMAIN. (
        $(date +%Y%m%d%H)
        3600
        1800
        604800
        86400 )

@       IN  NS  ns1.$INTERNAL_DOMAIN.
12      IN  PTR ns1.$INTERNAL_DOMAIN.
5       IN  PTR www.$INTERNAL_DOMAIN.
7       IN  PTR db.$INTERNAL_DOMAIN.
EOF"

# External Forward Lookup Zone
sudo bash -c "cat <<EOF > $FORWARD_EXTERNAL
\$TTL 86400
@   IN  SOA  ns1.$EXTERNAL_DOMAIN. admin.$EXTERNAL_DOMAIN. (
        $(date +%Y%m%d%H)
        3600
        1800
        604800
        86400 )

@       IN  NS  ns1.$EXTERNAL_DOMAIN.
ns1     IN  A   $EXTERNAL_NS_IP
www     IN  A   $EXTERNAL_NS_IP
shell   IN  A   172.18.14.6
files   IN  A   172.18.14.7
EOF"

# External Reverse Lookup Zone
sudo bash -c "cat <<EOF > $REVERSE_EXTERNAL
\$TTL 86400
@   IN  SOA  ns1.$EXTERNAL_DOMAIN. admin.$EXTERNAL_DOMAIN. (
        $(date +%Y%m%d%H)
        3600
        1800
        604800
        86400 )

@       IN  NS  ns1.$EXTERNAL_DOMAIN.
6       IN  PTR ns1.$EXTERNAL_DOMAIN.
14      IN  PTR shell.$EXTERNAL_DOMAIN.
EOF"

# Set correct permissions
sudo chown -R named:named "$ZONES_DIR"
sudo chmod 640 "$ZONES_DIR"/*
echo "Zone files created and permissions set." | tee -a $LOG_FILE

# Add zone configurations to named.conf (only if not already present)
if ! grep -q "$INTERNAL_DOMAIN" $NAMED_CONF; then
    sudo bash -c "cat <<EOF >> $NAMED_CONF

zone \"$INTERNAL_DOMAIN\" IN {
    type master;
    file \"zones/forward.$INTERNAL_DOMAIN\";
};

zone \"6.168.192.in-addr.arpa\" IN {
    type master;
    file \"zones/reverse.$INTERNAL_DOMAIN\";
};

zone \"$EXTERNAL_DOMAIN\" IN {
    type master;
    file \"zones/external.forward.$EXTERNAL_DOMAIN\";
};

zone \"13.18.172.in-addr.arpa\" IN {
    type master;
    file \"zones/external.reverse.$EXTERNAL_DOMAIN\";
};
EOF"
    echo "Added zone configurations to named.conf" | tee -a $LOG_FILE
else
    echo "Zone configurations already exist in named.conf. Skipping modification." | tee -a $LOG_FILE
fi

# Restart and enable BIND
sudo systemctl restart named
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to restart BIND. Check logs." | tee -a $LOG_FILE
    exit 1
else
    echo "BIND restarted successfully." | tee -a $LOG_FILE
fi
sudo systemctl enable named

# Open firewall for DNS
sudo firewall-cmd --add-service=dns --permanent
sudo firewall-cmd --reload
echo "Firewall updated to allow DNS traffic." | tee -a $LOG_FILE

# Display success message
echo "DNS Configuration Completed!" | tee -a $LOG_FILE
echo "Internal Forward Zone: $FORWARD_INTERNAL"
echo "Internal Reverse Zone: $REVERSE_INTERNAL"
echo "External Forward Zone: $FORWARD_EXTERNAL"
echo "External Reverse Zone: $REVERSE_EXTERNAL"
