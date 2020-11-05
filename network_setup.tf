
resource "aws_vpc" "vpc_master" {

  provider             = aws.region-master
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "master-vpc-jenkins"
  }
}

#Create VPC in eu-central-1
resource "aws_vpc" "vpc_workers" {

  provider             = aws.region-worker
  cidr_block           = "192.168.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "worker-vpc-jenkins"
  }
}

#Create IGW in eu-south-1
resource "aws_internet_gateway" "gateway_master" {
  provider = aws.region-master
  vpc_id   = aws_vpc.vpc_master.id
}

#Create IGW in eu-central-1
resource "aws_internet_gateway" "gateway_workers" {
  provider = aws.region-worker
  vpc_id   = aws_vpc.vpc_workers.id
}

#Initiate Peering connection request from eu-south-1
resource "aws_vpc_peering_connection" "master_workers_peering" {

  provider    = aws.region-master
  peer_vpc_id = aws_vpc.vpc_workers.id
  vpc_id      = aws_vpc.vpc_master.id
  peer_region = var.region-worker
}

#Accept VPC peering request in eu-central-1 from eu-south-1
resource "aws_vpc_peering_connection_accepter" "accept_peering_workers" {

  provider                  = aws.region-worker
  vpc_peering_connection_id = aws_vpc_peering_connection.master_workers_peering.id
  auto_accept               = true
}

#Create route table in eu-south-1
resource "aws_route_table" "internet_route" {

  provider = aws.region-master
  vpc_id   = aws_vpc.vpc_master.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway_master.id
  }
  route {
    cidr_block                = "192.168.1.0/24"
    vpc_peering_connection_id = aws_vpc_peering_connection.master_workers_peering.id
  }
  lifecycle {
    ignore_changes = all
  }
  tags = {
    Name = "Master-Region-RT"
  }
}

#Overwrite default route table of VPC(Master) with our route table entries
resource "aws_main_route_table_association" "set_master_default_rt_assoc" {
  provider       = aws.region-master
  vpc_id         = aws_vpc.vpc_master.id
  route_table_id = aws_route_table.internet_route.id
}

#Get all available AZ's in VPC for master region
data "aws_availability_zones" "avail_zones" {
  provider = aws.region-master
  state    = "available"
}

#Create subnet # 1 in eu-south-1
resource "aws_subnet" "subnet_1" {
  provider          = aws.region-master
  vpc_id            = aws_vpc.vpc_master.id
  availability_zone = element(data.aws_availability_zones.avail_zones.names, 0)
  cidr_block        = "10.0.1.0/24"
}

#Create subnet #2  in eu-south-1
resource "aws_subnet" "subnet_2" {
  provider          = aws.region-master
  vpc_id            = aws_vpc.vpc_master.id
  availability_zone = element(data.aws_availability_zones.avail_zones.names, 1)
  cidr_block        = "10.0.2.0/24"
}


#Create subnet in eu-central-1
resource "aws_subnet" "subnet_1_workers" {
  provider   = aws.region-worker
  vpc_id     = aws_vpc.vpc_workers.id
  cidr_block = "192.168.1.0/24"
}

#Create route table in eu-central-1
resource "aws_route_table" "internet_route_workers" {

  provider = aws.region-worker
  vpc_id   = aws_vpc.vpc_workers.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway_workers.id
  }
  route {
    cidr_block                = "10.0.1.0/24"
    vpc_peering_connection_id = aws_vpc_peering_connection.master_workers_peering.id
  }
  lifecycle {
    ignore_changes = all
  }
  tags = {
    Name = "Worker-Region-RT"
  }
}

#Overwrite default route table of VPC(Worker) with our route table entries
resource "aws_main_route_table_association" "set_worker_default_rt_assoc" {
  provider       = aws.region-worker
  vpc_id         = aws_vpc.vpc_workers.id
  route_table_id = aws_route_table.internet_route_workers.id
}


#Create SG for allowing TCP/8080 from * and TCP/22 from your IP in eu-south-1
resource "aws_security_group" "jenkins_master_sg" {

  provider    = aws.region-master
  name        = "jenkins_master_sg"
  description = "Allow TCP/8080 & TCP/22"
  vpc_id      = aws_vpc.vpc_master.id
  
  ingress {
    description = "Allow 22 from our public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.external_ip]
  }
  ingress {
    description     = "allow traffic from LB on port 8080"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.loadbalancer_sg.id]
  }
  ingress {
    description = "allow traffic from eu-central-1"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.1.0/24"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Create SG for LB, only TCP/80,TCP/443 and outgoing access
resource "aws_security_group" "loadbalancer_sg" {

  provider    = aws.region-master
  name        = "loadbalancer_sg"
  description = "Allow 443 and traffic to Jenkins SG"
  vpc_id      = aws_vpc.vpc_master.id

  ingress {
    description = "Allow 443 from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow 80 from anywhere for redirection"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Create SG for allowing TCP/22 from your IP in eu-central-1
resource "aws_security_group" "jenkins_workers_sg" {

  provider    = aws.region-worker
  name        = "jenkins_workers_sg"
  description = "Allow TCP/8080 & TCP/22"
  vpc_id      = aws_vpc.vpc_workers.id

  ingress {
    description = "Allow 22 from our public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.external_ip]
  }
  ingress {
    description = "Allow traffic from eu-south-1"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.1.0/24"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
