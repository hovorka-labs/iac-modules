# proxmox/images/talos

Downloads a Talos OS image to one or more Proxmox nodes using the [Talos Image Factory](https://factory.talos.dev). Supports custom extensions and automatically targets all nodes in the cluster when no node list is provided.

## Example

```hcl
provider "proxmox" {
  endpoint  = "https://pve.example.com:8006"
  api_token = "terraform@pve!provider=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  insecure  = true
}

module "talos_image" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/images/talos?ref=proxmox-talos-images-v1.0.0"

  talos_image_version  = "v1.9.5"
  talos_image_platform = "metal"

  talos_image_extensions = [
    "siderolabs/qemu-guest-agent",
  ]
}
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
