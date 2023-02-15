terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"
}

resource "aws_vpc" "myvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "vpc-ohio"
  }
}

resource "aws_subnet" "pubsub" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "pubsub-ohio"
  }
}

resource "aws_subnet" "pvtsub" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "pvtsub-ohio"
  }
}

resource "aws_internet_gateway" "myigw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "igw-ohio"
  }
}

resource "aws_route_table" "pub-rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.myigw.id
  }

  tags = {
    Name = "pubrt-ohio"
  }
}

resource "aws_route_table_association" "pubsubassociate" {
  subnet_id      = aws_subnet.pubsub.id
  route_table_id = aws_route_table.pub-rt.id
}

resource "aws_eip" "myeip" {
  vpc      = true
}

resource "aws_nat_gateway" "mynat" {
  allocation_id = aws_eip.myeip.id
  subnet_id     = aws_subnet.pubsub.id

  tags = {
    Name = "nat-ohio"
  }
}

resource "aws_route_table" "pvt-rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_nat_gateway.mynat.id
  }

  tags = {
    Name = "pvtrt-ohio"
  }
}

resource "aws_route_table_association" "pvtsubassociate" {
  subnet_id      = aws_subnet.pvtsub.id
  route_table_id = aws_route_table.pvt-rt.id
}

resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
      description      = "TLS from VPC"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
      description      = "TLS from VPC"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "pub-sg"
  }
}

resource "aws_instance" "pubec2" {
  ami                         =  "ami-0d718c3d715cec4a7"
  instance_type               =  "t2.micro"  
  subnet_id                   =  aws_subnet.pubsub.id
  key_name                    =  "linux-ohio"
  vpc_security_group_ids      =  [aws_security_group.allow_all.id]
  associate_public_ip_address =  true
}

resource "aws_instance" "pvtec2" {
  ami                         =  "ami-0d718c3d715cec4a7"
  instance_type               =  "t2.micro"  
  subnet_id                   =  aws_subnet.pvtsub.id
  key_name                    =  "linux-ohio"
  vpc_security_group_ids      =  [aws_security_group.allow_all.id]  
}