#!/bin/bash

# Set fixed team number
TEAM_NUMBER=6

# Prompt for domain name and name server IP
read -p "Enter the domain name (e.g., team6.net): " domain
read -p "Enter the IP address of the name server (e.g., 192.168.6.12): " ip_address
read -p "Enter the name of the user on the DNS server: " username

# Define paths for Rocky Linux 8
zones_folder="/var/named/zones"
forward_file="$zones_folder/forward.$domain"
reverse_file="$zones_folder/reverse.$domain"
external_forward_file="$zones_folder/external.forward.$domain"
external_reverse_file="$zones_folder/external.reverse.$domain"

# Ensure the zones folder exists
if [ ! -d "$zones_folder" ]; then
    sudo mkdir -p "$zones_folder"
    sudo chown -R named:named "$zones_folder"
    sudo chmod 750 "$zones_folder"
fi

# Determine reverse lookup zone
reverse_zone=$(echo $ip_address | awk -F. '{print $3"."$2"."$1}')
reverse_file="$zones_folder/$reverse_zone.in-addr.arpa"

# Copy named.empty as a base template for all zone files
sudo cp /var/named/named.empty "$forward_file"
sudo cp /var/named/named.empty "$reverse_file"
sudo cp /var/named/named.empty "$external_forward_file"
sudo cp /var/named/named.empty "$external_reverse_file"

# Populate the forward lookup file
sudo bash -c "cat <<EOF > $forward_file
\$TTL 86400
@   IN  SOA  ns1.$domain. admin.$domain. (
        $(date +%Y%m%d%H) ; Serial
        604800         ; Refresh
        86400         ; Retry
        2419200       ; Expire
        86400 )      ; Minimum TTL

; Name Servers
@       IN  NS  ns1.$domain.
ns1     IN  A   $ip_address
www     IN  A   192.168.6.5
db      IN  A   192.168.6.7
backup  IN  A   192.168.6.15
EOF"

# Populate the reverse lookup file
sudo bash -c "cat <<EOF > $reverse_file
\$TTL 86400
@   IN  SOA ns1.$domain. admin.$domain. (
        $(date +%Y%m%d%H) ; Serial
        3600         ; Refresh
        1800         ; Retry
        604800       ; Expire
        86400 )      ; Minimum TTL

; Reverse Lookup
@       IN  NS  ns1.$domain.
12      IN  PTR ns1.$domain.
5       IN  PTR www.$domain.
7       IN  PTR db.$domain.
15      IN  PTR backup.$domain.
EOF"

# Populate the external forward lookup file
sudo bash -c "cat <<EOF > $external_forward_file
\$TTL 86400
@   IN  SOA  ns1.$domain. admin.$domain. (
        $(date +%Y%m%d%H) ; Serial
        3600
        1800
        604800
        86400 )

@       IN  NS  ns1.$domain.
ns1     IN  A   172.18.13.6
www     IN  A   172.18.13.6
shell   IN  A   172.18.14.6
files   IN  A   172.18.14.7
EOF"

# Populate the external reverse lookup file
sudo bash -c "cat <<EOF > $external_reverse_file
\$TTL 86400
@   IN  SOA  ns1.$domain. admin.$domain. (
        $(date +%Y%m%d%H) ; Serial
        3600
        1800
        604800
        86400 )

@       IN  NS  ns1.$domain.
6       IN  PTR ns1.$domain.
14      IN  PTR shell.$domain.
EOF"

# Ensure correct permissions
sudo chown -R named:named "$zones_folder"
sudo chmod 640 "$zones_folder"/*

# Update named.conf to reference new zone files
sudo bash -c "cat <<EOF >> /etc/named.conf

zone \"$domain\" IN {
    type master;
    file \"zones/forward.$domain\";
};

zone \"6.168.192.in-addr.arpa\" IN {
    type master;
    file \"zones/reverse.$domain\";
};

zone \"$domain.ncaecybergames.org\" IN {
    type master;
    file \"zones/external.forward.$domain\";
};

zone \"13.18.172.in-addr.arpa\" IN {
    type master;
    file \"zones/external.reverse.$domain\";
};
EOF"

# Restart DNS service
sudo systemctl restart named
sudo systemctl enable named

# Display success message
echo "DNS Zone Configuration Completed!"
echo "Forward Zone: $forward_file"
echo "Reverse Zone: $reverse_file"
echo "External Forward Zone: $external_forward_file"
echo "External Reverse Zone: $external_reverse_file"
