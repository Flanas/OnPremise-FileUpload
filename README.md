# OnPremise-FileUpload

# 📡 Termux Rclone Cron Uploader

Automated log uploader script for Android using **Termux**, **rclone**, **WebDAV**, and **cron**, ideal for uploading `.txt` or `.log` files daily to your self-hosted server.

---

## 🚀 Overview

This project enables an Android device (via Termux) to:
- Upload logs or text files automatically using `rclone`
- Persist jobs across reboots with `Termux:Boot`
- Run daily backups using `crond` and `termux-job-scheduler`
- Log upload history and status diagnostics

You can configure:
- Dynamic folder paths on the remote server
- A secure WebDAV remote over HTTPS (via Caddy or similar)
- Automatic startup and scheduled uploads

---

## 🧰 Requirements

Install these apps from F-Droid or Play Store:
- **[Termux](https://f-droid.org/packages/com.termux/)**
- **[Termux:Boot](https://f-droid.org/packages/com.termux.boot/)**
- **[Termux:API](https://f-droid.org/packages/com.termux.api/)**

Enable Termux access to shared storage:
```bash
termux-setup-storage
```

## 🧪 On-Premise Server Setup
WebDAV Backend with Caddy:

Install Caddy and enable WebDAV using a plugin or Caddyfile:
``` bash
:443 {
  file_server
  webdav
  tls your-email@example.com
}
```
## Domain and DNS Setup:

Purchase a domain (e.g., via Namecheap, GoDaddy).

Set up a DNS resolver using Cloudflare.

Create an A or CNAME record pointing to your on-premise server IP or tunnel endpoint.

Recommended File Handling:

Configure your WebDAV server to write files to an SSD first, then move them (manually or via script) to a secondary drive for long-term storage.

This improves speed and reduces upload failure risks due to I/O bottlenecks.

## 🔧 Configuration with .env
For better security, store credentials and custom values in a .env file:

MAIN_FOLDER=MainFolderName
SUB_FOLDER=DeviceID
REMOTE_NAME=logswebdav
REMOTE_URL=https://your-domain.com
REMOTE_USER=youruser
REMOTE_PASS=yourpass
Then, modify your script to source .env:
source "$HOME/.env"

## 🛠️ First-Time Setup
After placing the .sh script on your device:
```bash
bash setup_rclone_cron.sh
```

## This script will:

Fix Termux mirror

Install required packages

Configure rclone WebDAV remote

Setup cron and job scheduler

Enable Termux:Boot auto-start

Create upload and diagnostic scripts

Upload logs for the first time

## 📝 File Extensions Handled
Currently, the script uploads:

app.txt

app.*.txt

You can modify the find command in upload_logs.sh to support any pattern:
```bash 
find /storage/emulated/0 -type f \( -name "*.log" -o -name "*.txt" \)
```
## ⚠️ Windows Line Ending Warning
If the .sh script was created or downloaded on Windows, it might use CRLF line endings which break execution in Termux.

To fix:

Open the file in Visual Studio Code

Bottom-right corner: click CRLF

Select LF

Save and try again in Termux

## 🔒 Preventing Job Termination
To ensure background jobs persist:

Use 
```bash
termux-wake-lock
```
to prevent sleep.

Use termux-notification with --ongoing to keep services alive.

Rely on both crond and termux-job-scheduler for redundancy.

## 📄 Output Files
Upload Log:
~/rclone_upload_MAIN_SUB.log

## Diagnostics Report:
/storage/emulated/0/Download/rclone_cron_status.txt

## 🧼 Maintenance Tips
Rotate logs weekly to avoid bloat.

Monitor upload failures via diagnostics file.

Periodically update Termux and rclone:
```bash
pkg update -y && pkg upgrade -y
```
rclone selfupdate

## 🔐 Security Notes
Never hardcode passwords in scripts. Use .env or Termux's termux-keystore.

Ensure WebDAV is served over HTTPS with a valid TLS certificate.

Use rclone obscure to store your password safely in rclone.conf.

## 📬 Support
Questions or contributions?
Open a pull request or start a discussion in this repo.
