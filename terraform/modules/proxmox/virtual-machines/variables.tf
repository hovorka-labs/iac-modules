variable "virtual_machines" {
  description = "Map holding definiton of Virtual Machines to create"
  type = map(object({
    node_name = string
    vm_id     = optional(number)
    name      = optional(string)
    })
  )
}
