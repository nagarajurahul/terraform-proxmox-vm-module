##############################################
# Local Variables & Template Rendering
##############################################

locals {
  # Select appropriate cloud-init template based on server type
  userdata_template = var.control_server ? "control-server-user-data.tpl" : "user-data.tpl"

  userdata_rendered = templatefile(
    "${path.module}/${local.userdata_template}",
    {
      HOSTNAME      = var.vm_hostname
      DNS_DOMAIN    = var.dns_domain
      CA_ROOT_CRT   = trimspace(var.ca_root_certificate)
      environment   = var.environment
      git_username  = var.git_username
      git_email     = var.git_email
      users         = var.users
      LOCK_PASSWORD = var.lock_password

      install_docker = var.install_docker

      ssh_client_alive_interval  = var.ssh_client_alive_interval
      ssh_client_alive_count_max = var.ssh_client_alive_count_max
      ssh_max_auth_tries         = var.ssh_max_auth_tries
      ssh_max_sessions           = var.ssh_max_sessions

      fail2ban_max_retry = var.fail2ban_max_retry
      fail2ban_ban_time  = var.fail2ban_ban_time
      fail2ban_find_time = var.fail2ban_find_time
    }
  )

  network_rendered = templatefile(
    "${path.module}/network-config.tpl",
    {
      DRIVER      = var.network_driver
      DNS_SERVERS = join(", ", [for s in var.dns_servers : format("%q", s)])
      DNS_DOMAIN  = var.dns_domain
    }
  )
}