variable "resource-group-name" {
  default = "terraform-application-resource-group1"
  description = "The prefix used for all resources in this example"
}

variable "app-service-name1" {
  default = "terraform-app-service1"
  description = "The name of the Web App1"
}
variable "app-service-name2" {
  default = "terraform-app-service2"
  description = "The name of the Web App2"
}

variable "location" {
  default = "West Europe"
  description = "The Azure location where all resources in this example should be created"
}
