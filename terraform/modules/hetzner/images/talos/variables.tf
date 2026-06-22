variable "talos_version" {
  description = "Talos OS version (e.g. v1.12.0)"
  type        = string
}

variable "extensions" {
  description = "List of Talos system extensions to include in the schematic. Ignored when schematic_id is set."
  type        = list(string)
  default     = []
}

variable "extra_kernel_args" {
  description = "Extra kernel arguments to include in the schematic. Ignored when schematic_id is set."
  type        = list(string)
  default     = []
}

variable "schematic_id" {
  description = "Pre-existing Talos image factory schematic ID. When set, skips schematic creation. Use Hetzner's public Talos ISO schematic: ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515 (includes qemu-guest-agent)."
  type        = string
  default     = null
}

variable "iso_name" {
  description = "Name of the Hetzner public Talos ISO (find with: hcloud iso list | grep -i talos). Defaults to talos-<talos_version>-hcloud-amd64."
  type        = string
  default     = null
}
