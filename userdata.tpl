#cloud-config

hostname: ${HOSTNAME}
fqdn: ${HOSTNAME}.${DNS_DOMAIN}

manage_etc_hosts: true
timezone: UTC

write_files:
%{ if CA_ROOT_CRT != "" ~}
  - path: /usr/local/share/ca-certificates/custom_root_ca.crt
    permissions: '0644'
    content: |
      ${join("\n      ", split("\n", trimspace(CA_ROOT_CRT)))}
%{ endif ~}

users:
%{ for username, user in users ~}
  - name: ${username}
    gecos: ${username}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: [sudo]
    shell: /bin/bash
    hashed_passwd: ${user.hashed_password}
    ssh_authorized_keys:
%{ for key in user.ssh_authorized_keys ~}
      - ${key}
%{ endfor ~}
    lock_passwd: false
%{ endfor ~}

ssh_pwauth: true  # Enable password authentication for SSH

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

bootcmd:
  - test -f /var/lib/cloud/bootcmd_done && exit 0 || touch /var/lib/cloud/bootcmd_done
  - echo "Ensuring network comes up before packages..." | tee -a /var/log/cloud-init-network.log
  - sleep 10
  - netplan generate
  - netplan apply || (sleep 5 && netplan apply)
  - systemctl restart systemd-networkd || true

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
