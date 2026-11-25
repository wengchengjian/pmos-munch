#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o ServerAliveInterval=15"
U=/mnt/f/project/pmos-munch/units
for f in containerd.service docker.service redis.service postgresql.service docker-daemon.json 90-docker.conf; do
  $SSH "$H" "cat > /tmp/$f" < "$U/$f" || exit 1
done
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
set -e
mkdir -p /etc/docker /etc/sysctl.d
install -m 644 /tmp/containerd.service /etc/systemd/system/containerd.service
install -m 644 /tmp/docker.service /etc/systemd/system/docker.service
install -m 644 /tmp/redis.service /etc/systemd/system/redis.service
install -m 644 /tmp/postgresql.service /etc/systemd/system/postgresql.service
install -m 644 /tmp/docker-daemon.json /etc/docker/daemon.json
install -m 644 /tmp/90-docker.conf /etc/sysctl.d/90-docker.conf
systemctl daemon-reload
echo units-installed
echo == initdb ==
if [ ! -f /var/lib/postgresql/data/PG_VERSION ]; then
  install -d -o postgres -g postgres -m 700 /var/lib/postgresql/data
  su -s /bin/sh postgres -c \"/usr/sbin/initdb -D /var/lib/postgresql/data -E UTF8 --locale=C --auth-local=peer --auth-host=scram-sha-256\" 2>&1 | tail -12
else
  echo already-initialized
fi
echo == enable ==
systemctl enable containerd.service docker.service redis.service postgresql.service 2>&1 | tail -8
echo == start containerd ==
timeout 60 systemctl start containerd.service; echo containerd-rc=\$?
sleep 2
systemctl is-active containerd.service
echo == start docker ==
timeout 90 systemctl start docker.service; echo docker-rc=\$?
sleep 2
systemctl is-active docker.service
echo == start redis ==
timeout 30 systemctl start redis.service; echo redis-rc=\$?
systemctl is-active redis.service
echo == start postgres ==
timeout 60 systemctl start postgresql.service; echo pg-rc=\$?
systemctl is-active postgresql.service
echo == failed ==
systemctl --failed --no-pager
"' 2>&1 | grep -a -v "Permanently added"