# talos/images

Looks up a Talos OS image from the [Talos Image Factory](https://factory.talos.dev) for a given version, platform, and set of extensions. Outputs the installer image URL for upgrades and machine configs, plus the ISO URL and expected Proxmox file path for the manual upload step below.

## Example

```hcl
module "talos_image" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/talos/images?ref=main"

  talos_image_version  = "v1.9.5"
  talos_image_platform = "metal"

  talos_image_extensions = [
    "siderolabs/qemu-guest-agent",
  ]
}
```

## Uploading the ISO

This module doesn't download the ISO itself - it's boot media only needed the first time a VM starts (upgrades pull `installer_image` directly over the network and never touch it again), so tying its download to every `tofu apply` wastes bandwidth and Proxmox storage for versions that never provision a new VM.

Instead, whenever you actually need a new VM to boot from this version, tell Proxmox to fetch it once per node yourself, via the API's `download-url` endpoint (there's no `pvesm` subcommand for this - `pvesm upload` doesn't exist, this is the same action the "Download from URL" button in the web UI performs):

```bash
curl -k -H "Authorization: PVEAPIToken=<user>@<realm>!<token-id>=<secret>" \
  -X POST "https://<proxmox-host>:8006/api2/json/nodes/<node>/storage/<datastore>/download-url" \
  --data-urlencode "content=iso" \
  --data-urlencode "filename=$(tofu output -raw iso_file_name)" \
  --data-urlencode "url=$(tofu output -raw iso_url)"
```

This returns a task UPID immediately (Proxmox downloads it server-side); poll `/nodes/<node>/tasks/<upid>/status` if you want to confirm it finished before applying. This module has no Proxmox awareness of its own - it doesn't know your datastore name or which nodes you're targeting - so build a VM's `cdrom` `file_id` yourself from `iso_file_name` and whatever datastore you uploaded to, e.g. `"${var.datastore.iso}:iso/${module.talos_image.iso_file_name}"`. Reference it only after the download above, or Proxmox will fail to attach it.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | ~> 0.11 |
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.11.0 |
## Modules

No modules.
## Resources

| Name | Type |
| ---- | ---- |
| [talos_image_factory_schematic.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/image_factory_schematic) | resource |
| [talos_image_factory_extensions_versions.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/image_factory_extensions_versions) | data source |
| [talos_image_factory_urls.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/image_factory_urls) | data source |
## Inputs

| Name | Description | Default | Required |
| ---- | ----------- | ------- | :------: |
| <a name="input_talos_image_platform"></a> [talos\_image\_platform](#input\_talos\_image\_platform) | Platform type for the Talos image (e.g., metal, nocloud, vmware) | n/a | yes |
| <a name="input_talos_image_version"></a> [talos\_image\_version](#input\_talos\_image\_version) | Talos OS version to use (e.g., v1.9.5) | n/a | yes |
| <a name="input_talos_image_extensions"></a> [talos\_image\_extensions](#input\_talos\_image\_extensions) | List of Talos extensions to include | `[]` | no |
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_installer_image"></a> [installer\_image](#output\_installer\_image) | Talos installer image URL for use in machine configs |
| <a name="output_iso_file_name"></a> [iso\_file\_name](#output\_iso\_file\_name) | File name to upload the ISO under on each Proxmox node's datastore - see the module README for the manual upload step. Combine with your own datastore name to build a VM's cdrom file\_id, e.g. "${datastore}:iso/${iso\_file\_name}". |
| <a name="output_iso_url"></a> [iso\_url](#output\_iso\_url) | Talos Image Factory URL to download the ISO from. Fetch this and upload it to Proxmox yourself - see the module README for the manual step. |
| <a name="output_schematic_id"></a> [schematic\_id](#output\_schematic\_id) | Talos image factory schematic ID |
<!-- END_TF_DOCS -->
