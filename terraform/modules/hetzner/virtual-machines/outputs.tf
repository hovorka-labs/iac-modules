output "servers" {
  description = "Map of server name to server details"
  value = {
    for name, server in hcloud_server.this : name => {
      id        = server.id
      public_ip = server.ipv4_address
      status    = server.status
    }
  }
}
