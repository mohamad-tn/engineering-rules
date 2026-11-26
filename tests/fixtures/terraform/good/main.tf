variable "name" {
  type        = string
  description = "Name of the thing."
  default     = "demo"
}

resource "terraform_data" "example" {
  input = var.name
}

output "name" {
  value = terraform_data.example.input
}
