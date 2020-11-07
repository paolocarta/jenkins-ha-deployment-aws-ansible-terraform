#Get Linux AMI ID using SSM Parameter endpoint in master region
data "aws_ssm_parameter" "linux_ami" {
  provider = aws.region-master
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

#Get Linux AMI ID using SSM Parameter endpoint in worker region
data "aws_ssm_parameter" "linux_ami_workers_region" {
  provider = aws.region-worker
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

#Create key-pair for logging into EC2 in master region
resource "aws_key_pair" "master-key" {
  provider   = aws.region-master
  key_name   = "jenkins"
  public_key = file("~/.ssh/jenkins-aws-ssh-access.pub")
}

#Create key-pair for logging into EC2 in worker region
resource "aws_key_pair" "worker-key" {
  provider   = aws.region-worker
  key_name   = "jenkins"
  public_key = file("~/.ssh/jenkins-aws-ssh-access.pub")
}

#Create and bootstrap EC2 instance 
resource "aws_instance" "jenkins_master" {

  provider                    = aws.region-master
  ami                         = data.aws_ssm_parameter.linux_ami.value
  instance_type               = var.instance-type
  key_name                    = aws_key_pair.master-key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins_master_sg.id]
  subnet_id                   = aws_subnet.subnet_1.id

  provisioner "local-exec" {
    command = <<EOF
      aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-master} --instance-ids ${self.id} \
      && ansible-playbook --extra-vars 'passed_in_hosts=tag_Name_${self.tags.Name}' --private-key=~/.ssh/jenkins-aws-ssh-access ansible_templates/install_jenkins.yaml
    EOF
  }
  tags = {
    Name = "jenkins_master_tf"
  }
  depends_on = [aws_main_route_table_association.set_master_default_rt_assoc]
}

#Create EC2 in eu-central-1
resource "aws_instance" "jenkins_worker" {

  provider                    = aws.region-worker
  count                       = var.workers-count
  ami                         = data.aws_ssm_parameter.linux_ami_workers_region.value
  instance_type               = var.instance-type
  key_name                    = aws_key_pair.worker-key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins_workers_sg.id]
  subnet_id                   = aws_subnet.subnet_1_workers.id

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "java -jar /home/ec2-user/jenkins-cli.jar -auth @/home/ec2-user/jenkins_auth -s http://${self.tags.Master_Private_IP}:8080 -auth @/home/ec2-user/jenkins_auth delete-node ${self.private_ip}"
    ]
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/jenkins-aws-ssh-access")
      host        = self.public_ip
    }
  }

  provisioner "local-exec" {
    command = <<EOF
      aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-worker} --instance-ids ${self.id} \
      && ansible-playbook --extra-vars 'passed_in_hosts=tag_Name_${self.tags.Name} master_ip=${aws_instance.jenkins_master.private_ip}' --private-key=~/.ssh/jenkins-aws-ssh-access ansible_templates/install_worker.yaml
    EOF
  }
  tags = {
    Name = join("_", ["jenkins_worker_tf", count.index + 1])
    Master_Private_IP = aws_instance.jenkins_master.private_ip
  }
  depends_on = [aws_main_route_table_association.set_worker_default_rt_assoc, aws_instance.jenkins_master]
}
