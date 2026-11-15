variable "release_name" {
  description = "Helm release name - required, since this module is reused for different payloads with no sensible shared default"
  type        = string
}

variable "namespace" {
  description = "The namespace Helm records this release under - set it to match whatever namespace the manifests themselves target, even when (as with a cluster-scoped CR) nothing in them actually needs one"
  type        = string
  default     = "default"
}

variable "create_namespace" {
  description = "Whether to create the namespace if it doesn't already exist - leave false when one of the manifests already declares its own Namespace object"
  type        = bool
  default     = false
}

variable "manifests" {
  description = "Pre-rendered Kubernetes manifests (full YAML documents, as strings) to apply as-is. The caller is responsible for any templating (file()/templatefile()) before passing them in - this module does no templating of its own, it only passes them through."
  type        = list(string)
  default     = []
}

variable "timeout" {
  description = "Helm install/upgrade timeout in seconds"
  type        = number
  default     = 600
}
