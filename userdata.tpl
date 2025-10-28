#cloud-config

hostname: ${HOSTNAME}
fqdn: ${HOSTNAME}.homelab.local
manage_etc_hosts: true

users:
%{ for username, user in users ~}
  - name: ${username}
    gecos: ${username}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: users, admin, sudo
    shell: /bin/bash
    ssh_authorized_keys:
%{ for key in user.ssh_authorized_keys ~}
      - ${key}
%{ endfor ~}
    lock_passwd: false
%{ endfor ~}

# Allow password login (required for OVF 'password' to work)
ssh_pwauth: true

chpasswd:
  list: |
%{ for username, user in users ~}
    ${username}:${user.password}
%{ endfor ~}
  expire: False

system_info:
  default_user:
    name: ${default_user}
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash

package_update: true
package_upgrade: true
package_reboot_if_required: true

packages:
  # --- Base System & Utilities ---
  - vim
  - nano
  - curl
  - wget
  - unzip
  - zip
  - jq
  - htop
  - tmux
  - gnupg
  - ca-certificates
  - software-properties-common
  - apt-transport-https
  - lsb-release
  - tree

  # --- Networking & Connectivity ---
  - net-tools
  - dnsutils
  - traceroute
  - iproute2
  - iputils-ping
  - socat
  - conntrack
  - ebtables
  - ethtool
  - nfs-common

  # --- Monitoring & Debugging ---
  - iotop
  - iftop
  - sysstat
  - nmon
  - ncdu

  # --- Security & Access ---
  - openssh-server
  - ufw
  - fail2ban
  - sudo

  # --- Proxmox Integration ---
  - qemu-guest-agent

  # --- Optional / Recommended ---
  - chrony
  - rsync
  - bash-completion

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - systemctl enable --now ssh
  - ufw allow OpenSSH
  - ufw --force enable
  - systemctl enable --now chrony
  - hostnamectl set-hostname ${HOSTNAME}
  - apt-get autoremove -y
  - sync
  - ip a >> /var/log/cloud-init-network.log
  - echo "Welcome to ${HOSTNAME}" > /etc/motd
  - echo "Cloud Init completed successfully on $(date)" | tee -a /var/log/cloud-init-done.log
