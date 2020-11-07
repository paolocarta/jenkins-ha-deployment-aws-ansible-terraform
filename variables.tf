variable "external_ip" {
  type    = string
  default = "0.0.0.0/0"
}

variable "instance-type" {
  type    = string
  default = "t3.micro"
}

# variable "dns-name" {
#   type    = string
#   default = "<public-hosted-zone-ending-with-dot>" 
# }

variable "profile" {
  type    = string
  default = "default"
}

variable "region-master" {
  type    = string
  default = "eu-central-1"
}

variable "region-worker" {
  type    = string
  default = "eu-west-3"
}

#How many Jenkins workers to spin up
variable "workers-count" {
  type    = number
  default = 1
}
