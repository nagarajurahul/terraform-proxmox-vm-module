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
  # Minimal useful tools for worker VMs
  - sudo
  - curl
  - wget
  - ca-certificates
  - gnupg
  - lsb-release
  - apt-transport-https
  - qemu-guest-agent
  - chrony           
  - iproute2
  - iputils-ping
  - net-tools
  - dnsutils
  - traceroute
  - bash-completion
  - rsync
  - lsof

  # Monitoring / debugging (small)
  - htop
  - ncdu
  - sysstat

  # Security
  - openssh-server
  # - ufw
  - fail2ban

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - systemctl enable --now ssh
  - systemctl enable --now chrony
  - systemctl enable --now fail2ban
  # - ufw allow OpenSSH
  # - ufw --force enable
   # small apt retry for transient failures (no heavy installs here)
  - apt-get update -y || (sleep 5 && apt-get update -y)
  - hostnamectl set-hostname ${HOSTNAME}
  - apt-get autoremove -y
  - sync
  - ip a >> /var/log/cloud-init-network.log
  - echo "Welcome to ${HOSTNAME}" > /etc/motd
  - echo "Cloud Init completed successfully on $(date)" | tee -a /var/log/cloud-init-done.log
  - touch /var/log/cloud-init.success