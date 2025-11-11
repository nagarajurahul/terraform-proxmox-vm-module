#cloud-config
version: 2
ethernets:
  eth0:
    dhcp4: true
    dhcp4-overrides:
      use-dns: false
    nameservers:
      addresses: [${DNS_SERVERS}]
      search: [${DNS_DOMAIN}]
