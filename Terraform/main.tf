terraform {
  cloud {
    organization = "tamim_hemat"

    workspaces {
      name = "4640-Terraform"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-west-2"
}

variable "base_cidr_block" {
  description = "default cidr block for vpc"
  default     = "10.0.0.0/16"
}

variable "subnet1_cidr_block" {
  description = "default cidr block for subnet1"
  default     = "10.0.1.0/24"
}

variable "subnet2_cidr_block" {
  description = "default cidr block for subnet2"
  default     = "10.0.2.0/24"
}

variable "subnet3_cidr_block" {
  description = "default cidr block for subnet3"
  default     = "10.0.3.0/24"
}

resource "aws_vpc" "main" {
  cidr_block       = var.base_cidr_block
  instance_tenancy = "default"

  tags = {
    Name = "acit-4640-vpc"
  }
}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet1_cidr_block
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "acit-4640-pub-sub"
  }
}

resource "aws_subnet" "sub2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet2_cidr_block
  availability_zone = "us-west-2a"

  tags = {
    Name = "acit-4640-rds-sub1"
  }
}

resource "aws_subnet" "sub3" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet3_cidr_block
  availability_zone = "us-west-2b"

  tags = {
    Name = "acit-4640-rds-sub2"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "acit-4640-igw"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "acit-4640-rt"
  }
}

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "sg-ec2" {
  name        = "acit-4640-sg-ec2"
  description = "Allow SSH and HTTP traffic from anywhere"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
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

resource "aws_security_group" "sg-rds" {
  name        = "acit-4640-sg-rds"
  description = "Allow MySQL traffic from within the VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "MySQL from within the VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.base_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "key" {
  key_name   = "acit-4640-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILvf+1MwjXpuYAj0C2aUEQ/QpRGJ8wk7bK8QtEdPpy9A tamim@Tamim-Vivobook-Flip14"
}

resource "aws_instance" "ec2" {
  ami                         = "ami-0735c191cf914754d"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.key.key_name
  subnet_id                   = aws_subnet.sub1.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg-ec2.id]

  tags = {
    Name = "acit-4640-ec2"
  }
}

resource "aws_db_subnet_group" "rds-subnet-group" {
  name       = "acit-4640-rds-subnet-group"
  subnet_ids = [aws_subnet.sub2.id, aws_subnet.sub3.id]

  tags = {
    Name = "acit-4640-rds-subnet-group"
  }
}

resource "aws_db_instance" "rds-db" {
  identifier             = "acit-4640-rds"
  engine                 = "mysql"
  engine_version         = "8.0.28"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  multi_az               = false
  username               = "admin"
  password               = "password"
  vpc_security_group_ids = [aws_security_group.sg-rds.id]
  db_subnet_group_name   = aws_db_subnet_group.rds-subnet-group.name
  publicly_accessible    = false
  skip_final_snapshot    = true
  apply_immediately      = true
  availability_zone      = "us-west-2a"

  tags = {
    Name = "acit-4640-rds"
  }
}

output "ec2_public_ip" {
  value       = aws_instance.ec2.public_ip
  description = "Public IP address of the EC2 instance"
}

output "rds_endpoint" {
  value       = aws_db_instance.rds-db.endpoint
  description = "Endpoint of the RDS instance. Follows the -h flag in the mysql command when connecting."
}

output "rds_username" {
  value       = aws_db_instance.rds-db.username
  description = "Username of the RDS instance. Follows the -u flag in the mysql command when connecting."
  sensitive   = true
}

output "rds_password" {
  value       = aws_db_instance.rds-db.password
  description = "Password of the RDS instance. Follows the -p flag in the mysql command when connecting."
  sensitive   = true
}
