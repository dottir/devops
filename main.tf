# brew install terraform
# docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/
provider "aws" {
    region = "us-east-1"
}

# in this terrform test:
# create vpc, igw, custom route table, subnet, sg, eni, eip, enable apache2

# vpc
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# igw
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main"
  }
}

# route-table
resource "aws_route_table" "testRT" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

#   route {
#     ipv6_cidr_block        = "::/0"
#     gateway_id  = aws_internet_gateway.gw.id
#   }

  tags = {
    Name = "main"
  }
}

# subnet
resource "aws_subnet" "test" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Test"
  }
}

# associate RT to subnet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.test.id
  route_table_id = aws_route_table.testRT.id
}

# sec grp
resource "aws_security_group" "allow_ssh" {
  name        = "allow_web"
  description = "a sg created from terraform test"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "for http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #anywhere
  }

  ingress {
    description = "for ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" #any
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "testsg"
  }
}

# network interface
resource "aws_network_interface" "test_nic" {
  subnet_id       = aws_subnet.test.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_ssh.id]
}

# eip
resource "aws_eip" "my_eip" {
  vpc                       = true
  network_interface         = aws_network_interface.test_nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}

# ec2
resource "aws_instance" "test-server" {
  ami           = "ami-0bcc094591f354be2" # Ubuntu Server 18.04 LTS (HVM), SSD Volume Type 
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "msw-key1" # no ".pem" in name!

  network_interface{
      device_index = 0
      network_interface_id = aws_network_interface.test_nic.id 
  }

#   user_data = <<-EOF 
#                 #!/bin/bash
#                 sudo apt update -y
#                 sudo apt install apache2 -y
#                 sudo systemctl start apache2
#                 EOF

  tags = {
    Name = "TerraformTestServer"
  }
}

# terrform init
# terraform apply --auto-approve
# ssh -i msw-key1.pem ubuntu@ip-here
