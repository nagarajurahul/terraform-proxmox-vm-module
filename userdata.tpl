#cloud-config

users:
%{ for username, user in users ~}
  - name: ${username}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    shell: /bin/bash
    ssh-authorized-keys:
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
  - systemctl enable --now qemu-guest-agent
  - systemctl enable --now ssh
  - ufw allow OpenSSH
  - ufw --force enable
  - systemctl enable --now chrony
  - hostnamectl set-hostname ${HOSTNAME}
  - ip a >> /var/log/cloud-init-network.log
  - echo "Welcome to ${HOSTNAME}" > /etc/motd
  - apt autoremove -y
  - echo "Cloud Init completed successfully. $(date)" >> /var/log/cloud-init-done.log