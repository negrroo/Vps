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

# How to Setup
wget -O Script.sh https://raw.githubusercontent.com/negrroo/Vps/main/Script.sh && chmod +x Script.sh
# Then
./Script.sh Digital/Akami - Falcon/Montazer/NTVIP/Dragon

# Time Change Step 1 or Step 2
dpkg-reconfigure tzdata
}

#Installition
Updates() {
# Debian Environment setup
apt-get update -y; apt-get upgrade -y;
CronMis
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

CronMis() {
# install cron if missing
command -v crontab >/dev/null 2>&1 || {
    apt install -y cron
    systemctl enable cron
    systemctl start cron
}
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

BlockingDomains7() {
rm -r /etc/block-sites/domains.txt
sudo tee /etc/block-sites/domains.txt > /dev/null <<'EOF'
# example:
# Certificate Verify
ppq.apple.com
# Also Block Local
#app.localhost.direct
# Block OTA
gdmf.apple.com
# Essensials
vpp.itunes.apple.com
appattest.apple.com
certs.apple.com
crl.apple.com
valid.apple.com
ocsp2.apple.com
ocsp.apple.com
# All
ocsp.int-x3.letsencrypt.org
oscp.apple.com
oscp2.appe.com
crl3.digicert.com
crl.entrust.net
crl4.digicert.com
ocsp.digicert.cn
ocsp.digicert.com
ocsp.entrust.net
ocsp.usertrust.com
ffapple.com
mesu.apple.com
world-gen.g.aaplimg.com
xp.apple.com
appldnld.apple.com
swscan.apple.com
pass.nekoo.apple
metrics.apple.com
# add or remove domains here
EOF
}

Expired1() {
sudo mkdir -p /var/lib/ssh-expiry
sudo touch /var/lib/ssh-expiry/expired_notified.list
sudo chmod 600 /var/lib/ssh-expiry/expired_notified.list
}

Expired2() {
sudo tee /usr/local/bin/ssh-expiry-check.sh > /dev/null <<'EOF'
#!/bin/bash

set -u
set -o pipefail

BOT_TOKEN="8296821742:AAFpCm8QA9nFSowF8J93D9EBnQR7MccfbnE"
CHAT_ID="453486843"


STATE_FILE="/var/lib/ssh-expiry/expired_notified.list"
TODAY=$(date +%s)
HOSTNAME=$(hostname)

send_telegram() {
    local MSG="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="$MSG" >/dev/null
}

# Get all normal users (UID >= 1000)
for user in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd); do
    EXP_DATE=$(chage -l "$user" | awk -F': ' '/Account expires/{print $2}')

    [[ "$EXP_DATE" == "never" ]] && continue

    EXP_TS=$(date -d "$EXP_DATE" +%s 2>/dev/null)
    [[ -z "$EXP_TS" ]] && continue

    if [[ "$EXP_TS" -le "$TODAY" ]]; then
        # User is expired
        if ! grep -qx "$user" "$STATE_FILE"; then
            send_telegram "⚠️ SSH user expired
👤 User: $user
🖥 Host: $HOSTNAME
🕒 $EXP_DATE"

            echo "$user" >> "$STATE_FILE"
        fi
    else
        # User is NOT expired → remove from state file if exists (renewed)
        sed -i "/^$user$/d" "$STATE_FILE"
    fi
done
EOF
}

Expired3() {
sudo chmod +x /usr/local/bin/ssh-expiry-check.sh
}

Expired4() {
# add cron job (runs daily at midnight)
(crontab -l 2>/dev/null | grep -v "ssh-expiry-check.sh"; echo "0 21 * * * /usr/local/bin/ssh-expiry-check.sh") | crontab -
}

LastLogin1() {
sudo tee /usr/local/bin/ssh_last_login_record.sh > /dev/null <<'EOF'
#!/bin/bash

USER="$PAM_USER"
IP="$PAM_RHOST"
DATE="$(date '+%Y-%m-%d %H:%M:%S')"

LOGDIR="/var/log/ssh-last-login"
LOGFILE="$LOGDIR/$USER"

mkdir -p "$LOGDIR"

echo "$DATE|$IP" > "$LOGFILE"
EOF
}

LastLogin2() {
chmod +x /usr/local/bin/ssh_last_login_record.sh
}

LastLogin3() {
grep -qxF 'session optional pam_exec.so seteuid /usr/local/bin/ssh_last_login_record.sh' /etc/pam.d/sshd || \
echo 'session optional pam_exec.so seteuid /usr/local/bin/ssh_last_login_record.sh' >> /etc/pam.d/sshd
}

Monitor1() {
sudo tee /usr/local/bin/ssh_user_monitor.sh > /dev/null <<'EOF'
#!/bin/bash

set -u
set -o pipefail

USERS_DB="/etc/firewallfalcon/users.db"
LOGIN_DIR="/var/log/ssh-last-login"
BW_DIR="/etc/firewallfalcon/bandwidth"

# detect if falcon usage exists
SHOW_USAGE=false
[[ -d "$BW_DIR" ]] && SHOW_USAGE=true

ssh_sessions_for_user() {
  local u="$1"
  ps -ef 2>/dev/null | awk -v user="$u" '
    $0 ~ "sshd: "user"@" {c++}
    $0 ~ "sshd: "user" \\[priv\\]" {c++}
    END {print c+0}
  '
}

format_date() {
  d="$1"

  if [[ "$d" == "Never" ]]; then
     echo "Never"
     return
  fi

  date -d "$d" +"%b %d %H:%M" 2>/dev/null || echo "$d"
}

get_usage_mb() {
  local user="$1"
  f="$BW_DIR/$user.usage"

  bytes=0
  [[ -f "$f" ]] && bytes=$(cat "$f")

  awk "BEGIN {printf \"%.2f\", $bytes/1024/1024}"
}

uptime_hms() {
  local up
  up=$(cut -d. -f1 /proc/uptime 2>/dev/null)
  printf "%02d:%02d:%02d" $((up/3600)) $(((up%3600)/60)) $((up%60))
}

online_list=()
offline_list=()

TODAY=$(date +%s)

while IFS= read -r line || [[ -n "$line" ]]; do

  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  u="${line%%:*}"

  [[ -z "$u" ]] && continue

  # EXCEPTION: skip users starting with x or v
  [[ "$u" =~ ^[xv] ]] && continue

  id "$u" >/dev/null 2>&1 || continue


  # skip expired users
  EXP_DATE=$(chage -l "$u" | awk -F': ' '/Account expires/{print $2}')
  if [[ "$EXP_DATE" != "never" ]]; then
      EXP_TS=$(date -d "$EXP_DATE" +%s 2>/dev/null)
      [[ -n "$EXP_TS" && "$EXP_TS" -le "$TODAY" ]] && continue
  fi


  sessions=$(ssh_sessions_for_user "$u")

  file="$LOGIN_DIR/$u"

  if [[ -f "$file" ]]; then
      raw_login=$(cut -d'|' -f1 "$file")
  else
      raw_login="Never"
  fi

  last_login=$(format_date "$raw_login")

  if $SHOW_USAGE; then
      usage=$(get_usage_mb "$u")

      row=$(printf "%-10s %-6s %12s %12s" \
      "$u" "$sessions" "$last_login" "$usage MB")

      key="$usage"

  else

      row=$(printf "%-10s %-6s %-5s" \
      "$u" "$sessions" "$last_login")

      key="0"

  fi

  if [[ "$sessions" -gt 0 ]]; then
     online_list+=("$key|$row")
  else
     offline_list+=("$key|$row")
  fi

done < "$USERS_DB"


online_count="${#online_list[@]}"
server_uptime=$(uptime_hms)

printf "\n"

if $SHOW_USAGE; then

printf "%-7s %-10s %-10s %12s\n" "USER($online_count)" SESSIONS LAST_LOGIN "($server_uptime)"
printf "%-7s %0s %10s %12s\n" ------ -------- ------ ------

else

printf "%-7s %-10s %-10s\n" "USER($online_count)" SESSIONS LAST_LOGIN
printf "%-7s %-10s %-10s\n" ---- -------- ----------

fi

IFS=$'\n'

# online users sorted by highest usage
for l in $(printf "%s\n" "${online_list[@]}" | sort -nr); do
   echo "${l#*|}"
done

# separator only if both exist
if [[ ${#online_list[@]} -gt 0 && ${#offline_list[@]} -gt 0 ]]; then
   printf "------------------------------------------------------\n"
fi

# offline users sorted by highest usage
for l in $(printf "%s\n" "${offline_list[@]}" | sort -nr); do
   echo "${l#*|}"
done

printf "\n"

exit 0
EOF
}

Monitor2() {
chmod +x /usr/local/bin/ssh_user_monitor.sh
}

Daily1() {
sudo tee /usr/local/bin/ssh-usage-daily.sh > /dev/null <<'EOF'
#!/bin/bash

BW_DIR="/etc/firewallfalcon/bandwidth"
DB_DIR="/var/log/ssh-usage"
STATE_FILE="$DB_DIR/last_values.db"

TODAY=$(date +%F)
YEAR=$(date +%Y)
MONTH=$(date +%m)

DAY_DIR="$DB_DIR/$YEAR/$MONTH"

mkdir -p "$DAY_DIR"
touch "$STATE_FILE"

TMP_FILE=$(mktemp)

while IFS= read -r file; do

  user=$(basename "$file" .usage)

  current_bytes=$(cat "$file")

  previous_bytes=$(grep "^$user " "$STATE_FILE" | awk '{print $2}')

  [[ -z "$previous_bytes" ]] && previous_bytes=0

  diff=$((current_bytes - previous_bytes))

  [[ "$diff" -lt 0 ]] && diff=0

  mb=$(awk "BEGIN {printf \"%.2f\", $diff/1024/1024}")

  echo "$user $current_bytes" >> "$TMP_FILE"

  echo "$user $mb MB" >> "$DAY_DIR/$TODAY.log"

done < <(find "$BW_DIR" -type f -name "*.usage")

mv "$TMP_FILE" "$STATE_FILE"

exit 0
EOF
}

Daily2() {
chmod +x /usr/local/bin/ssh-usage-daily.sh
}

Daily3() {
# add cron job (runs daily at midnight)
(crontab -l 2>/dev/null | grep -v "ssh-usage-daily.sh"; echo "0 21 * * * /usr/local/bin/ssh-usage-daily.sh") | crontab -
}

Monthly1() {
sudo tee /usr/local/bin/ssh-usage-reset-month.sh > /dev/null <<'EOF'
#!/bin/bash

BW_DIR="/etc/firewallfalcon/bandwidth"

for f in "$BW_DIR"/*.usage; do

  echo 0 > "$f"

done

exit 0
EOF
}

Monthly2() {
chmod +x /usr/local/bin/ssh-usage-reset-month.sh
}

Monthly3() {
# add cron job (runs daily at midnight)
(crontab -l 2>/dev/null | grep -v "ssh-usage-reset-month.sh"; echo "0 21 1 * * /usr/local/bin/ssh-usage-reset-month.sh") | crontab -
}

Usage1() {
sudo tee /usr/local/bin/ssh-usage-telegram.sh > /dev/null <<'EOF'
#!/bin/bash

BOT_TOKEN="8296821742:AAFpCm8QA9nFSowF8J93D9EBnQR7MccfbnE"
CHAT_ID="453486843"

BW_DIR="/etc/firewallfalcon/bandwidth"
DB_DIR="/var/log/ssh-usage"
STATE_FILE="$DB_DIR/month_start_values.db"

send_telegram() {
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
--data-urlencode "chat_id=${CHAT_ID}" \
--data-urlencode "text=$1" >/dev/null
}

TODAY=$(date +%F)
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)

MONTH_NAME=$(date +%B)

DAY_DIR="$DB_DIR/$YEAR/$MONTH"

mkdir -p "$DAY_DIR"
touch "$STATE_FILE"

TMP_BASE=$(mktemp)
TMP_SORT=$(mktemp)

TOTAL_BYTES=0

REPORT="📊 Daily Usage Report"$'\n'
REPORT+="📅 $TODAY"$'\n\n'


# if first day of month → create new baseline
if [[ "$DAY" == "01" ]]; then
    > "$STATE_FILE"

    for f in "$BW_DIR"/*.usage; do
        user=$(basename "$f" .usage)
        bytes=$(cat "$f")

        echo "$user $bytes" >> "$STATE_FILE"
    done
fi


while IFS= read -r file; do

    user=$(basename "$file" .usage)
    current_bytes=$(cat "$file")

    start_bytes=$(grep "^$user " "$STATE_FILE" | awk '{print $2}')
    [[ -z "$start_bytes" ]] && start_bytes=0

    diff=$((current_bytes - start_bytes))
    [[ "$diff" -lt 0 ]] && diff=0

    TOTAL_BYTES=$((TOTAL_BYTES + diff))

    # skip zero usage
    [[ "$diff" -eq 0 ]] && continue

    # convert usage
    usage=$(awk '
    BEGIN {
        mb='$diff'/1024/1024
        if (mb >= 1024)
            printf "%.2f GB", mb/1024
        else
            printf "%.2f MB", mb
    }')

    printf "%s %s\n" "$user" "$usage" >> "$DAY_DIR/$TODAY.log"

    echo "$diff|$(printf "%-10s %s" "$user" "$usage")" >> "$TMP_SORT"

done < <(find "$BW_DIR" -type f -name "*.usage")


# sort by real usage value
while IFS='|' read value line; do
    REPORT+="$line"$'\n'
done < <(sort -nr "$TMP_SORT")


TOTAL_USAGE=$(awk '
BEGIN {
    mb='$TOTAL_BYTES'/1024/1024
    if (mb >= 1024)
        printf "%.2f GB", mb/1024
    else
        printf "%.2f MB", mb
}')

REPORT+=$'\n'"Total today: $TOTAL_USAGE"

send_telegram "$REPORT"



# monthly report on first day of new month
if [[ "$DAY" == "01" ]]; then

MONTH_REPORT="📈 Monthly Usage Report"$'\n'
MONTH_REPORT+="📅 $MONTH_NAME $YEAR"$'\n\n'

MONTH_TOTAL=0

for f in "$DAY_DIR"/*.log; do

while read user usage unit; do

val=$(echo "$usage" | sed 's/[^0-9.]//g')

MONTH_TOTAL=$(awk "BEGIN {print $MONTH_TOTAL + $val}")

done < "$f"

done


MONTH_USAGE=$(awk '
BEGIN {
    mb='$MONTH_TOTAL'
    if (mb >= 1024)
        printf "%.2f GB", mb/1024
    else
        printf "%.2f MB", mb
}')

MONTH_REPORT+=$'\n'"Total month: $MONTH_USAGE"

send_telegram "$MONTH_REPORT"

fi


rm -f "$TMP_SORT" "$TMP_BASE"

exit 0
EOF
}

Usage2() {
chmod +x /usr/local/bin/ssh-usage-telegram.sh
}

Usage3() {
# add cron job (runs daily at midnight)
(crontab -l 2>/dev/null | grep -v "ssh-usage-telegram.sh"; echo "0 21 * * * /usr/local/bin/ssh-usage-telegram.sh") | crontab -
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
BlockingDomains7
Expired1
Expired2
Expired3
Expired4
LastLogin1
LastLogin2
LastLogin3
Monitor1
Monitor2
Daily1
Daily2
Daily3
Monthly1
Monthly2
Monthly3
Usage1
Usage2
Usage3
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
BlockingDomains7
Expired1
Expired2
Expired3
Expired4
LastLogin1
LastLogin2
LastLogin3
Monitor1
Monitor2
Daily1
Daily2
Daily3
Monthly1
Monthly2
Monthly3
Usage1
Usage2
Usage3
}

# Custom Proxy 8080
Proxy1() {
sudo mkdir -p /opt/pythonproxy
sudo tee /opt/pythonproxy/proxy.py > /dev/null <<'EOF'
#!/usr/bin/env python3

import socket
import threading
import select
import sys
import time

LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = 8080   # <-- تم تغييره إلى 8080

PASS = ''
BUFLEN = 4096 * 4
TIMEOUT = 60
DEFAULT_HOST = '127.0.0.1:22'

RESPONSE = (
    "HTTP/1.1 200 Connection Established\r\n"
    "Content-Length: 0\r\n\r\n"
).encode()


class Server(threading.Thread):
    def __init__(self, host, port):
        super().__init__()
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.lock = threading.Lock()

    def run(self):
        self.soc = socket.socket(socket.AF_INET)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.bind((self.host, self.port))
        self.soc.listen(100)
        self.running = True

        print(f"Listening on {self.host}:{self.port}")

        while self.running:
            try:
                client, addr = self.soc.accept()
                conn = ConnectionHandler(client, addr)
                conn.start()
                with self.lock:
                    self.threads.append(conn)
            except:
                pass

    def stop(self):
        self.running = False
        self.soc.close()


class ConnectionHandler(threading.Thread):
    def __init__(self, client, addr):
        super().__init__()
        self.client = client
        self.addr = addr
        self.target = None

    def run(self):
        try:
            data = self.client.recv(BUFLEN)
            headers = data.decode(errors='ignore')

            host = self.find_header(headers, 'X-Real-Host')
            if not host:
                host = DEFAULT_HOST

            self.connect_target(host)
            self.client.sendall(RESPONSE)
            self.forward()

        except Exception as e:
            print("Error:", e)
        finally:
            self.close()

    def find_header(self, headers, key):
        for line in headers.split("\r\n"):
            if line.startswith(key + ":"):
                return line.split(":", 1)[1].strip()
        return ''

    def connect_target(self, host):
        if ":" in host:
            h, p = host.split(":")
            port = int(p)
        else:
            h = host
            port = 22

        self.target = socket.create_connection((h, port))

    def forward(self):
        sockets = [self.client, self.target]
        while True:
            r, _, _ = select.select(sockets, [], [], 60)
            if not r:
                break

            for s in r:
                data = s.recv(BUFLEN)
                if not data:
                    return
                if s is self.client:
                    self.target.sendall(data)
                else:
                    self.client.sendall(data)

    def close(self):
        try:
            if self.client:
                self.client.close()
        except:
            pass
        try:
            if self.target:
                self.target.close()
        except:
            pass


if __name__ == '__main__':
    server = Server(LISTENING_ADDR, LISTENING_PORT)
    server.start()
    try:
        while True:
            time.sleep(2)
    except KeyboardInterrupt:
        server.stop()

EOF
}

Proxy2() {
chmod +x /opt/pythonproxy/proxy.py
}

Proxy3() {
sudo tee /etc/systemd/system/pythonproxy.service > /dev/null <<'EOF'
[Unit]
Description=Python TCP Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/pythonproxy/proxy.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
}

Proxy4() {
systemctl daemon-reload
systemctl enable pythonproxy
systemctl start pythonproxy
}


# If No Falcon
NoFalcon1() {
sudo tee /usr/local/bin/sync_users_db.sh > /dev/null <<'EOF'
#!/bin/bash

set -u
set -o pipefail

USERS_DB="/etc/firewallfalcon/users.db"

DEFAULT_EXPIRE="2099-12-31"
DEFAULT_CONN="99"

# Ensure file exists
mkdir -p "$(dirname "$USERS_DB")"
touch "$USERS_DB"

# Get real SSH users (home directory users)
awk -F: '$6 ~ /^\/home\// {print $1}' /etc/passwd | while read -r USER; do

    # Skip if already exists in USERS_DB
    if grep -q "^$USER:" "$USERS_DB"; then
        continue
    fi

    # Add user in required format
    echo "$USER:$USER:$DEFAULT_EXPIRE:$DEFAULT_CONN" >> "$USERS_DB"

done

exit 0
EOF
}

NoFalcon2() {
chmod +x /usr/local/bin/sync_users_db.sh
}

NoFalcon3() {
grep -qxF 'session optional pam_exec.so /usr/local/bin/sync_users_db.sh' /etc/pam.d/sshd || \
sed -i '/@include common-session/a session optional pam_exec.so /usr/local/bin/sync_users_db.sh' /etc/pam.d/sshd
}

NoFalcon4() {
# add cron job (runs daily at midnight)
(crontab -l 2>/dev/null | grep -v "sync_users_db.sh"; echo "0 21 * * * /usr/local/bin/sync_users_db.sh") | crontab -
}

onNTVIP() {
grep -q '^[^#].*reboot' /etc/cron.d/re_otm && \
sed -i 's|^\([^#].*reboot.*\)|#\1|' /etc/cron.d/re_otm
}

onMontazer() {
grep -q '^[^#].*reboot' /etc/cron.d/auto_reboot && \
sed -i 's|^\([^#].*reboot.*\)|#\1|' /etc/cron.d/auto_reboot
}

################

Falcon() {
curl -L -o install.sh "https://raw.githubusercontent.com/firewallfalcons/FirewallFalcon-Manager/main/install.sh" && chmod +x install.sh && sudo ./install.sh && rm install.sh
Finalizing
}

Montazer() {
wget https://raw.githubusercontent.com/MuntazerVpn/ehoop/main/installer -O installer && chmod +x installer && ./installer
Finalizing
onMontazer
NoFalcon1
NoFalcon2
NoFalcon3
NoFalcon4
Proxy1
Proxy2
Proxy3
Proxy4
}

Dragon() {
apt-get update -y; apt-get upgrade -y; wget https://raw.githubusercontent.com/sbatrow/DARKSSH-MANAGER/master/Dark; chmod 777 Dark; ./Dark
Finalizing
}

NTVIP() {
sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1 && apt update && apt install -y bzip2 gzip coreutils screen curl unzip && wget https://raw.githubusercontent.com/NETWORKTWEAKER/AUTO-SCRIPT/master/setup1.sh && chmod +x setup1.sh && sed -i -e 's/\r$//' setup1.sh && screen -S setup ./setup1.sh
Finalizing
onNTVIP
NoFalcon1
NoFalcon2
NoFalcon3
NoFalcon4
Proxy1
Proxy2
Proxy3
Proxy4
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

elif [ $Cond == 'Falcon' ]
then
Falcon

elif [ $Cond == 'Montazer' ]
then
Montazer

elif [ $Cond == 'Dragon' ]
then
Dragon

elif [ $Cond == 'NTVIP' ]
then
NTVIP

fi
################################LawRun-END#######################################
