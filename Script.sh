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

#Firewallx
Firewallx() {
########################################
# ensure ufw installed
########################################

if ! command -v ufw >/dev/null 2>&1; then
echo "Installing UFW..."
apt-get update -y >/dev/null 2>&1
apt-get install -y ufw >/dev/null 2>&1
fi

########################################
# firewall rules
########################################

ufw allow 22 >/dev/null 2>&1
ufw allow 80 >/dev/null 2>&1
ufw allow 443 >/dev/null 2>&1
ufw allow 8443 >/dev/null 2>&1
ufw allow 8080 >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1
ufw reload >/dev/null 2>&1
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
BlockingDomains2
BlockingDomains3
BlockingDomains4
BlockingDomains5
BlockingDomains6
BlockingDomains7
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
Expired2
Expired3
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

#########################################################
# SSH USERS
#########################################################

# Get all normal users (UID >= 1000)
for user in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd); do
    EXP_DATE=$(chage -l "$user" | awk -F': ' '/Account expires/{print $2}')

    [[ "$EXP_DATE" == "never" ]] && continue

    EXP_TS=$(date -d "$EXP_DATE" +%s 2>/dev/null)
    [[ -z "$EXP_TS" ]] && continue

    if [[ "$EXP_TS" -le "$TODAY" ]]; then

        if ! grep -qx "ssh:$user" "$STATE_FILE"; then

            send_telegram "⚠️ SSH user expired
👤 User: $user
🖥 Host: $HOSTNAME
🕒 $EXP_DATE"

            echo "ssh:$user" >> "$STATE_FILE"
        fi

    else

        sed -i "/^ssh:$user$/d" "$STATE_FILE"

    fi
done


#########################################################
# VMESS USERS
#########################################################

VMESS_DB="/etc/vmess-exp"

if [[ -f "$VMESS_DB" ]]; then

while read user exp status
do

    [[ -z "$user" ]] && continue

    EXP_TS=$(date -d "$exp" +%s 2>/dev/null)
    [[ -z "$EXP_TS" ]] && continue

    if [[ "$EXP_TS" -le "$TODAY" ]]; then

        if ! grep -qx "vmess:$user" "$STATE_FILE"; then

            send_telegram "⚠️ VMESS user expired
👤 User: $user
🖥 Host: $HOSTNAME
🕒 $exp"

            echo "vmess:$user" >> "$STATE_FILE"

        fi

    else

        sed -i "/^vmess:$user$/d" "$STATE_FILE"

    fi

done < "$VMESS_DB"

fi

EOF
}

Expired3() {
sudo chmod +x /usr/local/bin/ssh-expiry-check.sh
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
LastLogin2
LastLogin3
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

FALCON_DB="/etc/firewallfalcon/users.db"
USUARIOS_DB="/root/usuarios.db"
VMESS_DB="/etc/vmess-exp"
ACCESSLOG="/var/log/xray/access.log"

# 🔥 limit reading to avoid 100% CPU
TAIL_LINES=150

if [[ -f "$FALCON_DB" ]]; then
    USERS_DB="$FALCON_DB"

elif [[ -f "$USUARIOS_DB" ]]; then
    USERS_DB="$USUARIOS_DB"
    DB_TYPE="usuarios"

else
    echo "No users database found"
    exit 1
fi

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

############################################
# VMESS HELPERS (FIXED ONLY)
############################################

vmess_last_seen() {

user="$1"

tail -n $TAIL_LINES "$ACCESSLOG" 2>/dev/null \
| grep "email: $user" \
| tail -1 \
| awk '{print $1" "$2}'

}

vmess_sessions() {

user="$1"
now=$(date +%s)

tail -n $TAIL_LINES "$ACCESSLOG" 2>/dev/null \
| grep "email: $user" \
| awk -v now="$now" '

{
logtime=$1" "$2
gsub(/\//,"-",logtime)

cmd="date -d \""logtime"\" +%s"
cmd | getline t
close(cmd)

if ((now-t)<=120)
ips[$3]++

}

END {
print length(ips)
}
'

}

vmess_online_now() {

user="$1"
now=$(date +%s)

tail -n $TAIL_LINES "$ACCESSLOG" 2>/dev/null \
| grep "email: $user" \
| tail -n 5 \
| awk -v now="$now" '

{
logtime=$1" "$2
gsub(/\//,"-",logtime)

cmd="date -d \""logtime"\" +%s"
cmd | getline t
close(cmd)

if ((now-t)<=60) {
print 1
exit
}
}

END {
print 0
}
'

}

############################################

online_list=()
offline_list=()

TODAY=$(date +%s)

############################################
# ORIGINAL SSH LOOP (UNCHANGED)
############################################

while IFS= read -r line || [[ -n "$line" ]]; do

  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

  if [[ "${DB_TYPE:-falcon}" == "usuarios" ]]; then
      u=$(echo "$line" | awk '{print $1}')
  else
      u="${line%%:*}"
  fi

  [[ -z "$u" ]] && continue

  # EXCEPTION: skip users starting with x or v
  [[ "$u" =~ ^[xv] ]] && continue

  id "$u" >/dev/null 2>&1 || continue

  # hide system users
  [[ $(id -u "$u") -lt 1000 ]] && continue

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

############################################
# ADD VMESS USERS (NEW PART)
############################################

if [[ -f "$VMESS_DB" ]]; then

while read u exp
do

[[ -z "$u" ]] && continue

sessions=$(vmess_sessions "$u")

last_seen=$(vmess_last_seen "$u")

if [[ -z "$last_seen" ]]
then
last_login="Never"
else
last_login=$(format_date "$last_seen")
fi

if $SHOW_USAGE; then

usage=0

row=$(printf "%-10s %-6s %12s %12s" \
"$u" "$sessions" "$last_login" "$usage MB")

key="$usage"

else

row=$(printf "%-10s %-6s %-5s" \
"$u" "$sessions" "$last_login")

key="0"

fi

status=$(vmess_online_now "$u")

if [[ "$status" -eq 1 ]]
then
online_list+=("$key|$row")
else
offline_list+=("$key|$row")
fi

done < "$VMESS_DB"

fi

############################################
# ORIGINAL OUTPUT (UNCHANGED)
############################################

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
Monitor2
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
Daily2
}

Daily2() {
chmod +x /usr/local/bin/ssh-usage-daily.sh
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
Monthly2
}

Monthly2() {
chmod +x /usr/local/bin/ssh-usage-reset-month.sh
}

Usage1() {
sudo tee /usr/local/bin/ssh-usage-telegram.sh > /dev/null <<'EOF'
#!/bin/bash

BOT_TOKEN="8296821742:AAFpCm8QA9nFSowF8J93D9EBnQR7MccfbnE"
CHAT_ID="453486843"

BW_DIR="/etc/firewallfalcon/bandwidth"
DB_DIR="/var/log/ssh-usage"
STATE_FILE="$DB_DIR/last_day_values.db"

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

TMP_STATE=$(mktemp)
TMP_SORT=$(mktemp)

TOTAL_BYTES=0

REPORT="📊 Daily Usage Report"$'\n'
REPORT+="📅 $TODAY"$'\n\n'

while IFS= read -r file; do

    user=$(basename "$file" .usage)
    current_bytes=$(cat "$file")

    last_bytes=$(grep "^$user " "$STATE_FILE" | awk '{print $2}')
    [[ -z "$last_bytes" ]] && last_bytes=$current_bytes

    diff=$((current_bytes - last_bytes))
    [[ "$diff" -lt 0 ]] && diff=0

    TOTAL_BYTES=$((TOTAL_BYTES + diff))

    echo "$user $current_bytes" >> "$TMP_STATE"

    [[ "$diff" -eq 0 ]] && continue

    usage=$(awk '
    BEGIN {
        mb='$diff'/1024/1024
        if (mb >= 1024)
            printf "%.2f GB", mb/1024
        else
            printf "%.2f MB", mb
    }')

    printf "%-10s %s\n" "$user" "$usage" >> "$DAY_DIR/$TODAY.log"

    echo "$diff|$(printf "%-10s %s" "$user" "$usage")" >> "$TMP_SORT"

done < <(find "$BW_DIR" -type f -name "*.usage")

mv "$TMP_STATE" "$STATE_FILE"


while IFS='|' read bytes line; do
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



# monthly report (1st day)
if [[ "$DAY" == "01" ]]; then

PREV_MONTH=$(date -d "1 month ago" +%m)
PREV_YEAR=$(date -d "1 month ago" +%Y)
PREV_MONTH_NAME=$(date -d "1 month ago" +%B)

PREV_DIR="$DB_DIR/$PREV_YEAR/$PREV_MONTH"

TMP_MONTH_SORT=$(mktemp)

declare -A USER_TOTAL

for f in "$PREV_DIR"/*.log; do

while read user value unit; do

num=$(echo "$value" | sed 's/[^0-9.]//g')

# convert GB → MB
if echo "$value" | grep -q GB; then
    num=$(awk "BEGIN {print $num * 1024}")
fi

USER_TOTAL["$user"]=$(awk "BEGIN {print ${USER_TOTAL[$user]:-0} + $num}")

done < "$f"

done


MONTH_REPORT="📈 Monthly Usage Report"$'\n'
MONTH_REPORT+="📅 $PREV_MONTH_NAME $PREV_YEAR"$'\n\n'

MONTH_TOTAL=0

for user in "${!USER_TOTAL[@]}"; do

mb=${USER_TOTAL[$user]}

usage=$(awk '
BEGIN {
    mb='$mb'
    if (mb >= 1024)
        printf "%.2f GB", mb/1024
    else
        printf "%.2f MB", mb
}')

echo "$mb|$(printf "%-10s %s" "$user" "$usage")" >> "$TMP_MONTH_SORT"

MONTH_TOTAL=$(awk "BEGIN {print $MONTH_TOTAL + $mb}")

done


while IFS='|' read bytes line; do
    MONTH_REPORT+="$line"$'\n'
done < <(sort -nr "$TMP_MONTH_SORT")


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

rm -f "$TMP_MONTH_SORT"

fi


rm -f "$TMP_SORT"

exit 0
EOF
Usage2
}

Usage2() {
chmod +x /usr/local/bin/ssh-usage-telegram.sh
}

Akami() {
Updates
Dependencies
BlockingDomains1
Expired1
LastLogin1
Monitor1
}

Digital() {
Updates
Firewall
Dependencies
BlockingDomains1
Expired1
LastLogin1
Monitor1
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
Proxy2
Proxy3
Proxy4
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
NoFalcon2
NoFalcon3
}

NoFalcon2() {
chmod +x /usr/local/bin/sync_users_db.sh
}

NoFalcon3() {
grep -qxF 'session optional pam_exec.so /usr/local/bin/sync_users_db.sh' /etc/pam.d/sshd || \
sed -i '/@include common-session/a session optional pam_exec.so /usr/local/bin/sync_users_db.sh' /etc/pam.d/sshd
}

onNTVIP() {
grep -q '^[^#].*reboot' /etc/cron.d/re_otm && \
sed -i 's|^\([^#].*reboot.*\)|#\1|' /etc/cron.d/re_otm
}

onMontazer() {
grep -q '^[^#].*reboot' /etc/cron.d/auto_reboot && \
sed -i 's|^\([^#].*reboot.*\)|#\1|' /etc/cron.d/auto_reboot
}

CronTablet() {
CRON_TMP=$(mktemp)

crontab -l 2>/dev/null > "$CRON_TMP"

add_job() {
  local schedule="$1"
  local script="$2"

  # only add if script exists
  if [[ -x "$script" ]]; then
    # remove old entry
    sed -i "\|$script|d" "$CRON_TMP"

    # add new one
    echo "$schedule $script >/dev/null 2>&1" >> "$CRON_TMP"
  fi
}

# SSH jobs
add_job "0 0 * * *" /usr/local/bin/ssh-expiry-check.sh
add_job "0 0 * * *" /usr/local/bin/ssh-usage-daily.sh
add_job "0 0 1 * *" /usr/local/bin/ssh-usage-reset-month.sh
add_job "0 0 * * *" /usr/local/bin/ssh-usage-telegram.sh
add_job "0 0 * * *" /usr/local/bin/sync_users_db.sh

crontab "$CRON_TMP"
rm -f "$CRON_TMP"
}


# menuV2rayIntegration
menuv() {
sudo tee /usr/local/bin/menuv > /dev/null <<'EOF'
#!/bin/bash

menuv() {

vmess_db="/etc/vmess-exp"
ACCESSLOG="/var/log/xray/access.log"

############################################
# DETECT INSTALLATION
############################################

is_installed() {
    systemctl list-unit-files | grep -q xray.service
}

############################################
# INSTALL / UNINSTALL
############################################

	fun_bar() {
		comando[0]="$1"
		comando[1]="$2"
		(
			[[ -e $HOME/fim ]] && rm $HOME/fim
			[[ ! -d /etc/VPSManager ]] && rm -rf /bin/menu
			${comando[0]} >/dev/null 2>&1
			${comando[1]} >/dev/null 2>&1
			touch $HOME/fim
		) >/dev/null 2>&1 &
		tput civis
		echo -ne "\033[1;33mPLEASE WAIT... \033[1;37m- \033[1;33m["
		while true; do
			for ((i = 0; i < 18; i++)); do
				echo -ne "\033[1;31m#"
				sleep 0.1s
			done
			[[ -e $HOME/fim ]] && rm $HOME/fim && break
			echo -e "\033[1;33m]"
			sleep 1s
			tput cuu1
			tput dl1
			echo -ne "\033[1;33mPLEASE WAIT... \033[1;37m- \033[1;33m["
		done
		echo -e "\033[1;33m]\033[1;37m -\033[1;32m DONE !\033[1;37m"
		tput cnorm
	}



install_v2ray() {
                clear
                echo -e "\E[44;1;37m           V2RAY INSTALLER             \E[0m"
                echo -e "\n\033[1;33mVC ARE ABOUT TO INSTALL V2RAY !\033[0m"
                echo ""
                echo -e "\n\033[1;32mDOWNLOADING INSTALLER...\033[0m"
                wget -q -O /usr/local/sbin/install-vmess https://raw.githubusercontent.com/negrroo/Vps/main/Scripts/WOLF-VPS-MANAGER/Modulos/V2ray/install-vmess && chmod +x /usr/local/sbin/install-vmess
                wget -q -O /usr/local/sbin/vmess-modules https://raw.githubusercontent.com/negrroo/Vps/main/Scripts/WOLF-VPS-MANAGER/Modulos/V2ray/vmess-modules && chmod +x /usr/local/sbin/vmess-modules
                wget -q -O /usr/local/sbin/update-vmess https://raw.githubusercontent.com/negrroo/Vps/main/Scripts/WOLF-VPS-MANAGER/Modulos/V2ray/update-vmess && chmod +x /usr/local/sbin/update-vmess
                wget -q -O /usr/local/sbin/domaincek https://raw.githubusercontent.com/negrroo/Vps/main/Scripts/MineV2ray/domaincek && chmod +x /usr/local/sbin/domaincek
                echo ""
                echo -e "\033[1;32mINSTALLING V2RAY CORE...\033[0m"
                echo ""
                bash /usr/local/sbin/domaincek
                fun_bar 'bash /usr/local/sbin/install-vmess'
                echo ""
                echo -e "\033[1;32mINSTALLING USER MODULES...\033[0m"
                echo ""
                fun_bar 'bash /usr/local/sbin/vmess-modules'
                echo ""
                echo -e "\033[1;32mV2RAY INSTALLED SUCCESSFULLY!\033[0m"
                echo ""
                sleep 3
}

uninstall_v2ray() {
				clear
				echo -e "\E[44;1;37m           V2RAY UNINSTALLER             \E[0m"
				echo -e "\n\033[1;33mVC ARE ABOUT TO UNINSTALL V2RAY !\033[0m"
				echo ""
				echo "Stopping services..."
				systemctl stop xray 2>/dev/null
				systemctl disable xray 2>/dev/null
				echo "Removing xray..."
				[ -f /usr/local/bin/xray ] && rm -f /usr/local/bin/xray
				[ -d /usr/local/etc/xray ] && rm -rf /usr/local/etc/xray
				[ -d /var/log/xray ] && rm -rf /var/log/xray
				[ -f /etc/systemd/system/xray.service ] && rm -f /etc/systemd/system/xray.service
				[ -f /etc/systemd/system/xray@.service ] && rm -f /etc/systemd/system/xray@.service
				systemctl daemon-reload
				echo "Removing VMESS modules..."
				files=(
				/usr/local/sbin/add-vmess
				/usr/local/sbin/del-vmess
				/usr/local/sbin/list-vmess
				/usr/local/sbin/renew-vmess
				/usr/local/sbin/lock-vmess
				/usr/local/sbin/unlock-vmess
				/usr/local/sbin/config-vmess
				/usr/local/sbin/cek-vmess
				/usr/local/sbin/ip-vmess
				/usr/local/sbin/usage-vmess
				/usr/local/sbin/live-vmess
				/usr/local/sbin/check-vmess-ip
				/usr/local/sbin/check-vmess-exp
				/usr/local/sbin/_vmess_select_user
				/usr/local/sbin/vmenu
				/usr/local/sbin/vmess
				/usr/local/sbin/vmess-modules
				/usr/local/sbin/install-vmess
				/usr/local/sbin/domaincek
				)
				for f in "${files[@]}"
				do
				[ -f "$f" ] && rm -f "$f"
				done
				echo "Removing database..."
				[ -f /etc/vmess-exp ] && rm -f /etc/vmess-exp
				[ -f /etc/vmess-iplimit ] && rm -f /etc/vmess-iplimit
				echo "Cleaning cron jobs..."
				crontab -l 2>/dev/null | grep -v vmess | crontab -
				echo ""
				echo "V2RAY removed successfully"
}

############################################
# SYSTEM INFO
############################################

system=$(awk '{print $1" "$2}' /etc/issue.net)

_ram=$(free -h | awk '/Mem:/ {print $2}')
_usor=$(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2 }')
_usop=$(top -bn1 | awk '/Cpu/ {print 100 - $8 "%"}')
_core=$(grep -c cpu[0-9] /proc/stat)
_hora=$(date +%H:%M:%S)

############################################
# VMESS STATS
############################################

LOGTMP=$(tail -n 100 "$ACCESSLOG" 2>/dev/null)

_onli=$(echo "$LOGTMP" | grep "$(date +"%Y/%m/%d %H:%M")" \
| grep 'email:' \
| awk -F'email:' '{print $2}' \
| awk '{print $1}' \
| sort -u | wc -l)

_expuser=$(awk '$3=="locked"' $vmess_db 2>/dev/null | wc -l)
_tuser=$(grep -c "" $vmess_db 2>/dev/null)

############################################

while true; do

clear

installed=false
is_installed && installed=true

echo -e "\033[0;34m◇───────────────────────────────────────────────◇\033[0m"
echo -e "\E[41;1;37m      •ㅤ🌀   V2RAY MANAGER   🌀ㅤ•        \E[0m"
echo -e "\E[41;1;37m   •ㅤ🌀   NEGRROO VPS PANEL   🌀ㅤ•       \E[0m"
echo -e "\033[0;34m◇───────────────────────────────────────────────◇\033[0m"

echo -e "\033[1;32m◇ㅤSYSTEM          ◇ㅤRAM MEMORY    ◇ㅤPROCESSOR"
echo -e "\033[1;31mOS: \033[1;37m$system \033[1;31mTotal:\033[1;37m$_ram \033[1;31mCPU cores: \033[1;37m$_core\033[0m"
echo -e "\033[1;31mUp Time: \033[1;37m$_hora  \033[1;31mIn use: \033[1;37m$_usor \033[1;31mIn use: \033[1;37m$_usop\033[0m"

echo -e "\033[0;34m◇───────────────────────────────────────────────◇\033[0m"

echo -e "\033[1;32m◇ㅤOnline:\033[1;37m $_onli   \033[1;31m◇ㅤexpired: \033[1;37m$_expuser\033[1;33m◇ㅤTotal: \033[1;37m$_tuser\033[0m"

echo -e "\033[0;34m◇───────────────────────────────────────────────◇\033[0m"
echo ""

############################################
# MENU (MATCHED STYLE)
############################################

if $installed; then

echo -e "\033[1;31m[\033[1;36m01\033[1;31m] \033[1;37m◇ \033[1;33mADD USER \033[1;31m           [\033[1;36m08\033[1;31m] \033[1;37m◇ \033[1;33mVMESS LINK
[\033[1;36m02\033[1;31m] \033[1;37m◇ \033[1;33mDELETE USER \033[1;31m        [\033[1;36m09\033[1;31m] \033[1;37m◇ \033[1;33mONLINE USER
[\033[1;36m03\033[1;31m] \033[1;37m◇ \033[1;33mRENEW USER \033[1;31m         [\033[1;36m10\033[1;31m] \033[1;37m◇ \033[1;33mDOMAINS
[\033[1;36m04\033[1;31m] \033[1;37m◇ \033[1;33mLOCK USER \033[1;31m          [\033[1;36m11\033[1;31m] \033[1;37m◇ \033[1;33mBANDWIDTH
[\033[1;36m05\033[1;31m] \033[1;37m◇ \033[1;33mUNLOCK USER \033[1;31m        [\033[1;36m12\033[1;31m] \033[1;37m◇ \033[1;33mUPDATE SCRIPT
[\033[1;36m06\033[1;31m] \033[1;37m◇ \033[1;33mLIST USER \033[1;31m          [\033[1;36m13\033[1;31m] \033[1;37m◇ \033[1;33mUNINSTALL V2RAY
[\033[1;36m07\033[1;31m] \033[1;37m◇ \033[1;33mADD TEMP USER \033[1;31m      [\033[1;36m00\033[1;31m] \033[1;37m◇ \033[1;33mGET OUT \033[1;32m<\033[1;33m<\033[1;31m<"

else

echo -e "\033[1;31m[\033[1;36m01\033[1;31m] \033[1;37m◇ \033[1;33mADD USER \033[1;31m           [\033[1;36m08\033[1;31m] \033[1;37m◇ \033[1;33mVMESS LINK
[\033[1;36m02\033[1;31m] \033[1;37m◇ \033[1;33mDELETE USER \033[1;31m        [\033[1;36m09\033[1;31m] \033[1;37m◇ \033[1;33mONLINE USER
[\033[1;36m03\033[1;31m] \033[1;37m◇ \033[1;33mRENEW USER \033[1;31m         [\033[1;36m10\033[1;31m] \033[1;37m◇ \033[1;33mDOMAINS
[\033[1;36m04\033[1;31m] \033[1;37m◇ \033[1;33mLOCK USER \033[1;31m          [\033[1;36m11\033[1;31m] \033[1;37m◇ \033[1;33mINSTALL V2RAY
[\033[1;36m05\033[1;31m] \033[1;37m◇ \033[1;33mUNLOCK USER \033[1;31m        [\033[1;36m12\033[1;31m] \033[1;37m◇ \033[1;33mUPDATE SCRIPT
[\033[1;36m06\033[1;31m] \033[1;37m◇ \033[1;33mLIST USER \033[1;31m          [\033[1;36m00\033[1;31m] \033[1;37m◇ \033[1;33mGET OUT \033[1;32m<\033[1;33m<\033[1;31m<
[\033[1;36m07\033[1;31m] \033[1;37m◇ \033[1;33mADD TEMP USER"

fi

echo ""
echo -e "\033[0;34m◇───────────────────────────────────────────────◇\033[0m"
echo ""
echo -ne "\033[1;32m◇ WHAT DO YOU WANT TO DO \033[1;33m?\033[1;31m?\033[1;37m : "
read x

case "$x" in
01) 
   clear
   add-vmess 
   echo -ne "\n\033[1;31m◇ ENTER \033[1;33mto return to \033[1;32mMENU!\033[0m"; read
   ;;
02)
   clear
   del-vmess 
   echo -ne "\n\033[1;31m◇ ENTER \033[1;33mto return to \033[1;32mMENU!\033[0m"; read
;;
03)
   clear
   renew-vmess
   echo -ne "\n\033[1;31m◇ ENTER \033[1;33mto return to \033[1;32mMENU!\033[0m"; read
;;
04)
   clear
   lock-vmess
   echo -ne "\n\033[1;31m◇ ENTER \033[1;33mto return to \033[1;32mMENU!\033[0m"; read
;;
05)
   clear
   unlock-vmess
   echo -ne "\n\033[1;31m◇ ENTER \033[1;33mto return to \033[1;32mMENU!\033[0m"; read
;;
06)
   clear
   list-vmess
   echo -ne "\n\033[1;31m◇ ENTER \033[1;33mto return to \033[1;32mMENU!\033[0m"; read
;;
07)
   clear
   add-trial-vmess
   echo -ne "\n\033[1;31m◇ ENTER \033[1;33mto return to \033[1;32mMENU!\033[0m"; read
;;
08)
   clear
   config-vmess
   echo -ne "\n\033[1;31m◇ ENTER \033[1;33mto return to \033[1;32mMENU!\033[0m"; read
;;
09)
   clear
   cek-vmess
   echo -ne "\n\033[1;31m◇ ENTER \033[1;33mto return to \033[1;32mMENU!\033[0m"; read
;;
10)
   clear
   vmess-domain
   echo -ne "\n\033[1;31m◇ ENTER \033[1;33mto return to \033[1;32mMENU!\033[0m"; read
;;
11)
   clear
    if $installed; then
        usage-vmess
    else
        install_v2ray
    fi
   echo -ne "\n\033[1;31m◇ ENTER \033[1;33mto return to \033[1;32mMENU!\033[0m"; read
;;
12) 
   clear
   update-vmess
   echo -ne "\n\033[1;31m◇ ENTER \033[1;33mto return to \033[1;32mMENU!\033[0m"; read
;;
13)
   clear
    if $installed; then
        uninstall_v2ray
    fi
   echo -ne "\n\033[1;31m◇ ENTER \033[1;33mto return to \033[1;32mMENU!\033[0m"; read
;;
00|0) exit ;;
*) echo "Invalid"; sleep 1 ;;
esac

done
}

menuv
EOF

chmod +x /usr/local/bin/menuv
}

################

Falcon() {
Daily1
Monthly1
Usage1
curl -L -o install.sh "https://raw.githubusercontent.com/firewallfalcons/FirewallFalcon-Manager/main/install.sh" && chmod +x install.sh && sudo ./install.sh && rm install.sh
CronTablet
Finalizing
}

Montazer() {
NoFalcon1
Proxy1
wget https://raw.githubusercontent.com/MuntazerVpn/ehoop/main/installer -O installer && chmod +x installer && ./installer
CronTablet
Finalizing
onMontazer
}

Dragon() {
apt-get update -y; apt-get upgrade -y; wget https://raw.githubusercontent.com/sbatrow/DARKSSH-MANAGER/master/Dark; chmod 777 Dark; ./Dark
CronTablet
Finalizing
}

NTVIP() {
NoFalcon1
Proxy1
# sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1 && apt update && 
apt install -y bzip2 gzip coreutils screen curl unzip && wget https://raw.githubusercontent.com/NETWORKTWEAKER/AUTO-SCRIPT/master/setup1.sh && chmod +x setup1.sh && sed -i -e 's/\r$//' setup1.sh && screen -S setup ./setup1.sh
CronTablet
Finalizing
onNTVIP
}

zNTVIP() {
NoFalcon1
Proxy1
# sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1 && apt update && 
apt install -y bzip2 gzip coreutils screen curl unzip && wget https://raw.githubusercontent.com/V3SAKURAAIRIV3/Error404/main/setup.sh && chmod +x setup.sh && sed -i -e 's/\r$//' setup.sh && screen -S setup ./setup.sh
CronTablet
Finalizing
onNTVIP
}

Wolf() {
Firewallx
wget -q https://raw.githubusercontent.com/AtizaD/WOLF-VPS-MANAGER/main/hehe -q; chmod 777 hehe; ./hehe
wget -q -O /bin/conexao https://raw.githubusercontent.com/negrroo/Vps/main/Scripts/WOLF-VPS-MANAGER/Modulos/V2ray/vconexao && chmod +x /bin/conexao
CronTablet
Finalizing
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

elif [ $Cond == 'zNTVIP' ]
then
zNTVIP

elif [ $Cond == 'Init' ]
then
BlockingDomains1
Expired1
LastLogin1
Monitor1

elif [ $Cond == 'Usage' ]
then
Daily1
Monthly1
Usage1

elif [ $Cond == 'NoFalc' ]
then
NoFalcon1

elif [ $Cond == 'Prox' ]
then
Proxy1

elif [ $Cond == 'Wolf' ]
then
Wolf

elif [ $Cond == 'menuv' ]
then
menuv

fi
################################LawRun-END#######################################
