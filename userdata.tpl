#cloud-config

##############################################
# System Identity
#############################################

hostname: ${HOSTNAME}
fqdn: ${HOSTNAME}.${DNS_DOMAIN}

manage_etc_hosts: true
timezone: UTC

##############################################
# Write Files Before Package Installation
#############################################
write_files:
%{ if CA_ROOT_CRT != "" ~}
  - path: /usr/local/share/ca-certificates/custom_root_ca.crt
    permissions: '0644'
    owner: root:root
    content: |
      ${join("\n      ", split("\n", trimspace(CA_ROOT_CRT)))}
%{ endif ~}

##############################################
# User Configuration
#############################################
users:
%{ for username, user in users ~}
  - name: ${username}
    gecos: ${username}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: [ sudo, adm, systemd-journal ]
    shell: /bin/bash
    hashed_passwd: ${user.hashed_password}
    ssh_authorized_keys:
%{ for key in user.ssh_authorized_keys ~}
      - ${key}
%{ endfor ~}
    lock_passwd: false
%{ endfor ~}

# Enable password authentication for SSH in Lab (disable in production)
ssh_pwauth: true

##############################################
# Package Management
#############################################
package_update: true
package_upgrade: true
package_reboot_if_required: true

packages:
# Essential System Tools
- sudo
- curl
- wget
- ca-certificates
- gnupg
- lsb-release
- apt-transport-https
- software-properties-common

# QEMU Guest Agent (Critical for Proxmox, To get IP as well)
- qemu-guest-agent

# Time Synchronization
- chrony

# Networking Tools
- iproute2
- iputils-ping
- net-tools
- dnsutils
- traceroute
- netcat-openbsd

# System Monitoring
- htop
- iotop
- ncdu
- sysstat
- lsof

# Security
- openssh-server
- fail2ban
- unattended-upgrades

# Python (for Ansible)
- python3
- python3-pip
- python3-apt

# Miscellaneous
- vim
- rsync
- bash-completion

##############################################
# Boot Commands (Run Before Packages)
#############################################
bootcmd:
  - test -f /var/lib/cloud/bootcmd_done && exit 0 || touch /var/lib/cloud/bootcmd_done
  - echo "Ensuring network comes up before packages..." | tee -a /var/log/cloud-init-network.log
  - sleep 10
  - netplan generate
  - netplan apply || (sleep 5 && netplan apply)
  - systemctl restart systemd-networkd || true

##############################################
# Run Commands (After Package Installation)
#############################################
runcmd:
%{ if CA_ROOT_CRT != "" ~}
  - update-ca-certificates
%{ endif ~}
  - systemctl enable --now qemu-guest-agent
  - systemctl restart qemu-guest-agent || true
  - systemctl enable --now ssh
  - systemctl enable --now chrony
  - systemctl enable --now fail2ban
  # - ufw allow OpenSSH
  # - ufw --force enable
  - hostnamectl set-hostname ${HOSTNAME}
  - apt-get autoremove -y
  - sync
  - ip a >> /var/log/cloud-init-network.log
  - echo "Welcome to ${HOSTNAME}" > /etc/motd
  - echo "Cloud Init completed successfully on $(date)" | tee -a /var/log/cloud-init-done.log
  - touch /var/log/cloud-init.success

final_message: "Cloud-init completed on ${HOSTNAME} at $(date -u)"
