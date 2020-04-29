variable "location" {
  default = "uksouth"
}

variable "resource_group_prefix" {
  default = "UKS-COVID19"
}

variable "environment" {
  type = string
}

variable "tags" {
    description       = "Tags to apply to created resources"
    type              = map(string)    
}