variable "name" {
  type    =   string
 default = "demo"
}

output "name" {
 value = var.name
}
