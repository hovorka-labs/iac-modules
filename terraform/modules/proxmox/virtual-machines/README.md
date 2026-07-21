# proxmox/virtual-machines

Creates and manages Proxmox VMs from a single map variable, covering the common cases in this homelab: cloud-init provisioning, cloning from a template, PCI/GPU passthrough, and forcing a rebuild on demand.

## Example

```hcl
module "vms" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/virtual-machines?ref=proxmox-virtual-machines-v1.0.0"

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

- **`recreation_hash`** feeds a `terraform_data` resource wired up via `replace_triggered_by`. It lets a VM be recreated (re-cloned, re-initialized, etc.) by bumping one value, without needing an unrelated argument to change first.
- **`cdrom` defaults to `ide3`**, because Proxmox always attaches the cloud-init drive on `ide2` — reusing it would silently break cloud-init.
- **`clone.retries`** exists because cloning a template under load on this cluster occasionally fails transiently; a couple of retries is cheaper than debugging it.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.111 |
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.111.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
## Modules

No modules.
## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_virtual_environment_vm.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |
| [terraform_data.vm_recreate_trigger](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
## Inputs

| Name | Description | Default | Required |
| ---- | ----------- | ------- | :------: |
| <a name="input_virtual_machines"></a> [virtual\_machines](#input\_virtual\_machines) | Map of VMs to create. Map key becomes the VM name. | n/a | yes |
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_mac_addresses"></a> [mac\_addresses](#output\_mac\_addresses) | MAC address of the first network device for each VM |
| <a name="output_virtual_machines"></a> [virtual\_machines](#output\_virtual\_machines) | The full proxmox\_virtual\_environment\_vm resource for each VM |
<!-- END_TF_DOCS -->
