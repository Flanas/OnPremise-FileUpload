#!/data/data/com.termux/files/usr/bin/bash
# Termux Cron Setup Script with rclone, Termux:Boot, termux-job-scheduler, and dynamic file finder

# === CONFIGURATION ===
MAIN_FOLDER="MAIN-FOLDER" #Change this to the name you want
SUB_FOLDER="SUB-FOLDER" #Change this to the name you want
REMOTE_NAME="logswebdav"
REMOTE="${REMOTE_NAME}:${MAIN_FOLDER}/${SUB_FOLDER}"
LOGFILE="$HOME/rclone_upload_${MAIN_FOLDER}_${SUB_FOLDER}.log"
CRON_SCHEDULE="0 0 * * *" #Change this for the times you want to upload
REMOTE_URL="https://url-ofyouronpremiseserver.com" #change this to the url of your on-premise server
REMOTE_USER="username" #change this to the username
REMOTE_PASS="password" #change this to the password

echo "🛠️ [$(date)] Starting setup and upload script..."

# === FIX TERMUX MIRROR ===
echo "🌐 Setting Termux package mirror to grimler.se..."
cat <<EOF > $PREFIX/etc/apt/sources.list
deb https://packages.termux.dev/apt/termux-main stable main
EOF

# === SYSTEM PREP ===
echo "📦 Updating and installing packages..."
pkg update -y && pkg upgrade -y
pkg install -y rclone tsu cronie termux-api termux-services termux-job-scheduler

# === ENABLE CROND ===
echo "⚙️ Setting up crond service..."
mkdir -p ~/.termux/sv/crond
if [ ! -f ~/.termux/sv/crond/run ]; then
  echo -e "#!/data/data/com.termux/files/usr/bin/bash\ncrond" > ~/.termux/sv/crond/run
  chmod +x ~/.termux/sv/crond/run
  echo "✅ crond service script created."
fi
sv-enable crond

# === TERMUX:BOOT STARTUP SCRIPT ===
echo "📝 Creating Termux:Boot startup script..."
mkdir -p ~/.termux/boot
cat <<'EOF' > ~/.termux/boot/start_cron.sh
#!/data/data/com.termux/files/usr/bin/bash
echo "📦 Waiting for storage mount..." >> $HOME/boot.log
COUNTER=0
until [ -d "/storage/emulated/0/Download" ]; do
  sleep 5
  COUNTER=$((COUNTER+1))
  [ $COUNTER -ge 12 ] && break
done
echo "🚀 Starting crond at $(date)" >> $HOME/boot.log

termux-wake-lock
(termux-notification --id 999 --title "📡 Termux Uploader" --content "Running rclone + crond" --ongoing) &

if ! pgrep -f crond >/dev/null; then
  /data/data/com.termux/files/usr/bin/crond
else
  echo "✅ crond already running on boot." >> $HOME/boot.log
fi
EOF
chmod +x ~/.termux/boot/start_cron.sh

# === RCLONE CONFIG ===
echo "🔧 Configuring rclone remote..."
mkdir -p ~/.config/rclone
if grep -q "\[$REMOTE_NAME\]" ~/.config/rclone/rclone.conf 2>/dev/null; then
  sed -i "/^\[$REMOTE_NAME\]/,/^$/d" ~/.config/rclone/rclone.conf
fi
cat <<EOF >> ~/.config/rclone/rclone.conf
[$REMOTE_NAME]
type = webdav
url = $REMOTE_URL
vendor = other
user = $REMOTE_USER
pass = $(rclone obscure "$REMOTE_PASS")
skip_verify = true

EOF

# === CREATE UPLOAD SCRIPT (dynamic) ===
echo "📤 Creating upload_logs.sh..."
cat <<EOF > $HOME/upload_logs.sh
#!/data/data/com.termux/files/usr/bin/bash
MAIN_FOLDER="${MAIN_FOLDER}"
SUB_FOLDER="${SUB_FOLDER}"
REMOTE_NAME="${REMOTE_NAME}"
REMOTE="\${REMOTE_NAME}:\${MAIN_FOLDER}/\${SUB_FOLDER}"
LOGFILE="\$HOME/rclone_upload_\${MAIN_FOLDER}_\${SUB_FOLDER}.log"
echo "[\$(date)] 🔍 Scanning and uploading logs..." >> "\$LOGFILE"

# Upload matching .txt files with dynamic remote path
find /storage/emulated/0 -type f \\( -name "app.txt" -o -name "app.*.txt" \\) | while read -r file; do
    basename=\$(basename "\$file")
    echo "📤 Uploading \$basename" >> "\$LOGFILE"
    rclone copyto "\$file" "\$REMOTE/\$basename" \\
        --log-level INFO \\
        --log-file="\$LOGFILE"
done
EOF
chmod +x $HOME/upload_logs.sh

# === CRON SETUP ===
echo "🧹 Cleaning existing crontab..."
crontab -r 2>/dev/null || true

echo "🕒 Setting up fresh cron jobs..."
cat <<EOF | crontab -
# Primary job
$CRON_SCHEDULE bash $HOME/upload_logs.sh
# Safety retry
30 12 * * * bash $HOME/upload_logs.sh
# Daily diagnostics
30 0 * * * bash $HOME/gen_rclone_status.sh
EOF

# === TERMUX JOBSCHEDULER SETUP ===
echo "📅 Scheduling job with termux-job-scheduler..."
termux-job-scheduler --script $HOME/upload_logs.sh --period-ms 86400000 --persisted true --job-id 123

# === ENABLE WAKE LOCK AND NOTIFICATION ===
echo "🔒 Enabling wake-lock and persistent notification..."
termux-wake-lock
(termux-notification --id 999 --title "📡 Termux Uploader" --content "Running rclone + crond" --ongoing) &

# === START CROND ===
if ! pgrep -f crond >/dev/null; then
  crond
else
  echo "✅ crond is already running."
fi
sleep 1
pgrep -f crond >/dev/null && echo "✅ crond is running." || echo "🚩 Failed to start crond."

# === FIRST-TIME UPLOAD ===
echo "⚡ Running first-time upload now..."
bash $HOME/upload_logs.sh
echo "📄 Last 10 lines of rclone log:"
tail -n 10 "$LOGFILE"

# === DAILY DIAGNOSTIC REPORT ===
STATUS_FILE="/storage/emulated/0/Download/rclone_cron_status.txt"
echo "🕒 Daily Rclone Cron Status Report" > "$STATUS_FILE"
echo "Date: $(date)" >> "$STATUS_FILE"
echo "------------------------------" >> "$STATUS_FILE"
pgrep -f crond >/dev/null && echo "✅ crond is running." >> "$STATUS_FILE" || echo "❌ crond is NOT running!" >> "$STATUS_FILE"
echo -e "\n📄 Last 20 lines of rclone log ($LOGFILE):" >> "$STATUS_FILE"
[ -f "$LOGFILE" ] && tail -n 100 "$LOGFILE" >> "$STATUS_FILE" || echo "⚠️ Log file not found: $LOGFILE" >> "$STATUS_FILE"
echo "✅ Diagnostic file saved to: $STATUS_FILE"