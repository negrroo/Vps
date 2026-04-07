################################################################################
            #     Lawrun Build Script For Building Vps        #
            #                Credits To MEEEE                 #
            #              ###Made By negrroo###              #
            #=================================================#
            #        **          ******      negrroo          #
            #        **          *    *      **   **          #
            #        **          ******      **  **           #
            #        **          **          *****            #
            #        *******     ** **       **  **           #
            #        *******     **   **     **   **          #
            #=================================================#
###############################LawRun-Script####################################

# Set first parameter to Cond
Cond=$1

#Required Specifications
Specifications() {
Debian 11

# Time Change Step 1 or Step 2
dpkg-reconfigure tzdata
}

#Installition
Updates() {
# Debian Environment setup
apt-get update -y; apt-get upgrade -y;
}

#Installition
Firewall() {
# Requirements before installation the Firewall for blocking domains (Except Akami Server)
apt install -y dnsutils; apt install -y nftables;
}

#Installition
Dependencies() {
# Requirements before installation the falcon script
apt install -y bc; apt install -y jq;

}

#Finalizing
Finalizing() {
# Time Change Step 1 or Step 2
sudo timedatectl set-timezone Asia/Riyadh
}


##--__--Firstly the blocking domain script
BlockingDomains1() {
sudo mkdir -p /etc/block-sites
sudo tee /etc/block-sites/domains.txt > /dev/null <<'EOF'
# example:
# Essensials
vpp.itunes.apple.com
appattest.apple.com
certs.apple.com
crl.apple.com
valid.apple.com
ocsp2.apple.com
ocsp.apple.com
# add or remove domains here
EOF
}

BlockingDomains2() {
sudo tee /usr/local/bin/update-blocked-ips.sh > /dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

DOMAIN_FILE="/etc/block-sites/domains.txt"
TMP4="/tmp/blocksites_ipv4.txt"
TMP6="/tmp/blocksites_ipv6.txt"
NFT_TABLE="inet"
NFT_TABLE_FILTER="filter"
NFT_SET4="blocked4"
NFT_SET6="blocked6"

# Ensure domain file exists
if [ ! -f "$DOMAIN_FILE" ]; then
  echo "Domain file not found: $DOMAIN_FILE" >&2
  exit 1
fi

# Build IP lists
: > "$TMP4"
: > "$TMP6"

while IFS= read -r line || [ -n "$line" ]; do
  # strip whitespace and skip comments/empty lines
  d="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [ -z "$d" ] && continue
  case "$d" in
    \#*) continue ;;
  esac

  # IPv4
  dig +short A "$d" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' >> "$TMP4" || true
  # IPv6
  dig +short AAAA "$d" | grep -E ':' >> "$TMP6" || true
done < "$DOMAIN_FILE"

# uniq + sort
if [ -s "$TMP4" ]; then
  sort -u "$TMP4" -o "$TMP4"
else
  > "$TMP4"
fi

if [ -s "$TMP6" ]; then
  sort -u "$TMP6" -o "$TMP6"
else
  > "$TMP6"
fi

# Ensure table exists
if ! nft list table inet "$NFT_TABLE_FILTER" >/dev/null 2>&1; then
  nft add table inet "$NFT_TABLE_FILTER"
fi

# Ensure sets exist (create if missing)
if ! nft list set inet "$NFT_TABLE_FILTER" "$NFT_SET4" >/dev/null 2>&1; then
  nft add set inet "$NFT_TABLE_FILTER" "$NFT_SET4" { type ipv4_addr\; flags interval\; }
fi
if ! nft list set inet "$NFT_TABLE_FILTER" "$NFT_SET6" >/dev/null 2>&1; then
  nft add set inet "$NFT_TABLE_FILTER" "$NFT_SET6" { type ipv6_addr\; flags interval\; }
fi

# Ensure chains exist (output + forward + nat prerouting for early drops)
nft list chain inet "$NFT_TABLE_FILTER" output >/dev/null 2>&1 || nft add chain inet "$NFT_TABLE_FILTER" output { type filter hook output priority 0 \; }
nft list chain inet "$NFT_TABLE_FILTER" forward >/dev/null 2>&1 || nft add chain inet "$NFT_TABLE_FILTER" forward { type filter hook forward priority 0 \; }

# Add drop rules for sets if not present
# IPv4 forward/output
if ! nft list ruleset | grep -q "ip daddr @${NFT_SET4} drop"; then
  nft insert rule inet "$NFT_TABLE_FILTER" forward ip daddr @${NFT_SET4} drop || true
  nft insert rule inet "$NFT_TABLE_FILTER" output ip daddr @${NFT_SET4} drop || true
fi
# IPv6 forward/output
if ! nft list ruleset | grep -q "ip6 daddr @${NFT_SET6} drop"; then
  nft insert rule inet "$NFT_TABLE_FILTER" forward ip6 daddr @${NFT_SET6} drop || true
  nft insert rule inet "$NFT_TABLE_FILTER" output ip6 daddr @${NFT_SET6} drop || true
fi

# Rebuild sets: flush then add elements
nft flush set inet "$NFT_TABLE_FILTER" "$NFT_SET4" >/dev/null 2>&1 || true
nft flush set inet "$NFT_TABLE_FILTER" "$NFT_SET6" >/dev/null 2>&1 || true

# Add ipv4 elements (if any)
if [ -s "$TMP4" ]; then
  elems=$(paste -sd, "$TMP4")
  # if adding many elements might exceed cmdline length; handle per-line add if that happens
  nft add element inet "$NFT_TABLE_FILTER" "$NFT_SET4" { $elems } 2>/dev/null || {
    # fallback: add line-by-line
    while read -r ip; do nft add element inet "$NFT_TABLE_FILTER" "$NFT_SET4" { $ip } 2>/dev/null || true; done < "$TMP4"
  }
fi

# Add ipv6 elements
if [ -s "$TMP6" ]; then
  elems6=$(paste -sd, "$TMP6")
  nft add element inet "$NFT_TABLE_FILTER" "$NFT_SET6" { $elems6 } 2>/dev/null || {
    while read -r ip; do nft add element inet "$NFT_TABLE_FILTER" "$NFT_SET6" { $ip } 2>/dev/null || true; done < "$TMP6"
  }
fi

echo "Updated blocked IP sets:"
echo "IPv4:"
nft list set inet "$NFT_TABLE_FILTER" "$NFT_SET4" || true
echo "IPv6:"
nft list set inet "$NFT_TABLE_FILTER" "$NFT_SET6" || true

exit 0
EOF
}

BlockingDomains3() {
sudo chmod +x /usr/local/bin/update-blocked-ips.sh
sudo /usr/local/bin/update-blocked-ips.sh
}

BlockingDomains4() {
sudo tee /etc/systemd/system/update-blocked-ips.service > /dev/null <<'EOF'
[Unit]
Description=Update blocked site IP sets

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-blocked-ips.sh
EOF
}

BlockingDomains5() {
sudo tee /etc/systemd/system/update-blocked-ips.timer > /dev/null <<'EOF'
[Unit]
Description=Run update-blocked-ips daily at 00:00

[Timer]
OnCalendar=*-*-* 00:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
}

BlockingDomains6() {
sudo systemctl daemon-reload
sudo systemctl enable --now update-blocked-ips.timer
sudo systemctl list-timers --all | grep update-blocked-ips
}


Akami() {
Updates
Dependencies
BlockingDomains1
BlockingDomains2
BlockingDomains3
BlockingDomains4
BlockingDomains5
BlockingDomains6
}

Digital() {
Updates
Firewall
Dependencies
BlockingDomains1
BlockingDomains2
BlockingDomains3
BlockingDomains4
BlockingDomains5
BlockingDomains6
}

#

# Script Selection
# Working with ./Script.sh beta/build ...
if [ $Cond == 'Akami' ]
then
Akami

elif [ $Cond == 'Digital' ]
then
Digital

fi
################################LawRun-END#######################################
