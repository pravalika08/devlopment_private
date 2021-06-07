terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.42.0"
    }
  }
  backend "s3" {
    bucket = "terraformstate01062021"
    key    = "Development"
    region = "us-esat-2"
  }
}
data "aws_availability_zones" "available" {
  state = "available"
}
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}
resource "aws_key_pair" "dev" {
  key_name   = "dev03"
  public_key = file("~/.ssh/id_rsa.pub")
}
resource "aws_vpc" "dev_vpc" {
  cidr_block           = var.cidr_dev_vpc
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "dev_vpc"
  }
}
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.dev_vpc.id
  cidr_block              = var.cidr_public_subnet
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "public_subnet"
  }
}
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.dev_vpc.id
  cidr_block              = var.cidr_private_subnet
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "private_subnet"
  }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.dev_vpc.id
  tags = {
    Name = "public_rt"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.dev_vpc.id
  tags = {
    Name = "public_igw"
  }
}
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
resource "aws_eip" "nat_eip" {
  vpc = true
  tags = {
    Name = "eip_nat"
  }
  depends_on = [aws_internet_gateway.igw

  ]
}
resource "aws_route_table" "private" {
  vpc_id     = aws_vpc.dev_vpc.id
  depends_on = [aws_nat_gateway.ngw]

  tags = {
    Name = "private_rt"
  }
}
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags = {
    Name = "private_ngw"
  }
}
resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.ngw.id
}

resource "aws_route_table_association" "public_subnet_assoc" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_subnet.id
}
resource "aws_route_table_association" "private_subnet_assoc" {
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private_subnet.id
}
resource "aws_security_group" "sg_0106" {
  name   = "sg_0106"
  vpc_id = aws_vpc.dev_vpc.id
}
resource "aws_security_group_rule" "allow-ssh" {
  from_port         = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.sg_0106.id
  to_port           = 22
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "allow-http" {
  from_port         = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.sg_0106.id
  to_port           = 80
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "allow-outbound" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.sg_0106.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_eip" "development" {
  instance = aws_instance.dev2.id
  vpc      = true
  depends_on = [
    aws_internet_gateway.igw
  ]
}
resource "aws_instance" "dev1" {
  ami                         = lookup(var.ami_type, var.aws_region)
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.dev.key_name
  security_groups             = [aws_security_group.sg_0106.id]
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.sg_0106.id]
  associate_public_ip_address = true
  availability_zone           = data.aws_availability_zones.available.names[0]
  user_data                   = <<-EOF
  #!/bin/bash
  mkdir /var/www/html/dev
    echo "<h1>Software deployment is all of the activities that make a software system</h1>" > /var/www/html/dev/index.html
    service httpd start
    chkconfig httpd on
EOF
  tags = {
    Name = "Development1"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd -y",

    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      password    = ""
      private_key = file("~/.ssh/id_rsa")
      host        = aws_instance.dev1.public_ip
    }
  }
}
resource "aws_instance" "dev2" {
  ami                         = lookup(var.ami_type, var.aws_region)
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.dev.key_name
  security_groups             = [aws_security_group.sg_0106.id]
  subnet_id                   = aws_subnet.private_subnet.id
  vpc_security_group_ids      = [aws_security_group.sg_0106.id]
  associate_public_ip_address = false
  availability_zone           = data.aws_availability_zones.available.names[1]
  user_data                   = <<-EOF
                                     #!/bin/bash
                                     mkdir /var/www/html/site
                                     echo "<h1>This is the site page</h1>" > /var/www/html/site/index.html
                                     service httpd start
                                     chkconfig httpd on
                                   EOF
  tags = {
    Name = "Development2"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd -y",
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      password    = ""
      private_key = file("~/.ssh/id_rsa")
      host        = aws_instance.dev2.public_ip
    }
  }
}
