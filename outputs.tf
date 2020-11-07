output "amiId-eu-south-1" {
  value = data.aws_ssm_parameter.linux_ami.value
}

output "amiId-eu-central-1" {
  value = data.aws_ssm_parameter.linux_ami_workers_region.value
}
output "Jenkins-Main-Node-Public-IP" {
  value = aws_instance.jenkins_master.public_ip
}
output "Jenkins-Main-Node-Private-IP" {
  value = aws_instance.jenkins_master.private_ip
}
output "Jenkins-Worker-Public-IPs" {
  value = {
    for instance in aws_instance.jenkins_worker :
    instance.id => instance.public_ip
  }
}
output "Jenkins-Worker-Private-IPs" {
  value = {
    for instance in aws_instance.jenkins_worker :
    instance.id => instance.private_ip
  }
}

# output "url" {
#   value = aws_route53_record.jenkins.fqdn
# }
