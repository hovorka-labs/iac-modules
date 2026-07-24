# proxmox/virtual-machines

Creates and manages Proxmox VMs from a single map variable, covering the common cases in this homelab: cloud-init provisioning, cloning from a template, and PCI/GPU passthrough.

## Example

```hcl
module "vms" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/virtual-machines?ref=proxmox-virtual-machines-v1.1.0"

  virtual_machines = {
    talos-cp-1 = {
      node_name = "pve1"
      cpu = {
        cores = 4
      }
      memory = {
        dedicated = 4096
      }

      network_devices = [
        {
          bridge = "vmbr0"
        }
      ]

      disks = [
        {
          datastore_id = "local-zfs"
          size         = 20
          file_id      = "local:iso/talos.img"
        }
      ]

      init = {
        datastore_id = "local-zfs"
        ipv4 = {
          address = "192.168.1.10/24"
          gateway = "192.168.1.1"
        }
      }
    }
  }
}
```

## Design notes

A couple of things here exist because of problems hit in practice, not because the provider needed it:

- **`cdrom` defaults to `ide3`**, because Proxmox always attaches the cloud-init drive on `ide2` — reusing it would silently break cloud-init.
- **`clone.retries`** exists because cloning a template under load on this cluster occasionally fails transiently; a couple of retries is cheaper than debugging it.
- **`cpu.type` has no default** - it's passed straight to the provider, which falls back to its own default (`qemu64`) if you don't set one. That default is a deliberately conservative, feature-poor virtual CPU model for cross-host migration compatibility, and it can be missing instruction sets a modern kernel expects - Talos VMs left on it can fail to boot in a way that looks like a Proxmox or networking problem, not a CPU one. Set it explicitly (`host` is usually the right call unless you need migration compatibility across mismatched hardware).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.111 |
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.111.1 |
## Modules

No modules.
## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_virtual_environment_vm.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |
## Inputs

| Name | Description | Default | Required |
| ---- | ----------- | ------- | :------: |
| <a name="input_virtual_machines"></a> [virtual\_machines](#input\_virtual\_machines) | Map of VMs to create. Map key becomes the VM name. | n/a | yes |
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_mac_addresses"></a> [mac\_addresses](#output\_mac\_addresses) | MAC address of the first network device for each VM |
<!-- END_TF_DOCS -->
