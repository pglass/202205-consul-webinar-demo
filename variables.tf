variable "region" {
  description = "AWS region to deploy to."
  type        = string
}

variable "lb_ingress_ips" {
  description = "A list of IP addresses that are permitted to access the applications."
  type        = list(string)
}

variable "suffix" {
  description = "A suffix to append to uniquely identify resources. If not provided a random suffix will be used."
  type        = string
  default     = ""
}
