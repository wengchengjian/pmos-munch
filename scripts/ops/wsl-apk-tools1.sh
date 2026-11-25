#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "apk update 2>&1 | tail -6; apk add \
  bash coreutils findutils grep sed gawk diffutils which file less \
  procps-ng psmisc util-linux tar xz zstd tree jq curl wget rsync \
  openssh-client ca-certificates bind-tools iproute2 net-tools netcat-openbsd socat \
  sqlite-libs libffi libstdc++ zlib readline libxml2 2>&1 | tail -50"' 2>&1 | grep -a -v "Permanently added" | tail -60
echo "== space/verify =="
$SSH "$H" 'df -h / | tail -1; for t in bash curl git htop python3 vim nano; do printf "%s: " $t; command -v $t || echo -; done; ls /etc/apk/world' 2>&1 | grep -a -v "Permanently added" | head -20
