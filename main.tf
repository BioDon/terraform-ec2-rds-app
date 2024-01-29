terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.34.0"
    }
  }
  required_version = "1.7.1"
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "project-vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "project-igw" {
  vpc_id = aws_vpc.project-vpc.id
}

resource "aws_subnet" "project-public-subnet" {
  count             = var.public_subnet_count
  vpc_id            = aws_vpc.project-vpc.id
  cidr_block        = var.public_subnet_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "project-public-subnet-${count.index}"
  }
}

resource "aws_subnet" "project-private-subnet" {
  count             = var.private_subnet_count
  vpc_id            = aws_vpc.project-vpc.id
  cidr_block        = var.private_subnet_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "project-private-subnet-${count.index}"
  }
}

resource "aws_route_table" "project-public-route-table" {
  vpc_id = aws_vpc.project-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.project-igw.id
  }
}

resource "aws_route_table_association" "project-public-route-table-association" {
  count          = var.public_subnet_count // the number of subnets we want to associate with the route table
  subnet_id      = aws_subnet.project-public-subnet[count.index].id
  route_table_id = aws_route_table.project-public-route-table.id
}

resource "aws_route_table" "project-private-route-table" {
  vpc_id = aws_vpc.project-vpc.id
  // no route defined because we don't want to allow internet access to private subnets
}

resource "aws_route_table_association" "project-private-route-table-association" {
  count          = var.private_subnet_count // the number of subnets we want to associate with the route table
  subnet_id      = aws_subnet.project-private-subnet[count.index].id
  route_table_id = aws_route_table.project-private-route-table.id
}

// EC2 Security Group 
resource "aws_security_group" "project-ec2-sg" {
  name        = "project-ec2-sg"
  description = "Allow inbound traffic from port 22 and 80"
  vpc_id      = aws_vpc.project-vpc.id
  ingress {
    description = "Allow all traffic through HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow SSH from my computer"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// RDS Security Group
resource "aws_security_group" "project-db-sg" {
  name        = "project-db-sg"
  description = "Security Group for Project DB"
  vpc_id      = aws_vpc.project-vpc.id
  ingress {
    description     = "Allow DB traffic only from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.project-ec2-sg.id]
  }
}

// Creating DB Subnet Group before creating MySQL RDS instance
resource "aws_db_subnet_group" "project-db-subnet-group" {
  name        = "project-db-subnet-group"
  description = "DB Subnet Group for Project DB"
  subnet_ids  = aws_subnet.project-private-subnet[*].id
}

// Creating MySQL RDS instance
resource "aws_db_instance" "projectdatabase" {
  db_name             = var.settings.database.db_name
  engine              = var.settings.database.engine
  engine_version      = var.settings.database.engine_version
  instance_class      = var.settings.database.instance_class
  allocated_storage   = var.settings.database.allocated_storage
  skip_final_snapshot = var.settings.database.skip_final_snapshot

  vpc_security_group_ids = [aws_security_group.project-db-sg.id]            # Security group for the datatbase
  db_subnet_group_name   = aws_db_subnet_group.project-db-subnet-group.name # DB subnet group name
  username               = var.db_username
  password               = var.db_password
}

/* Before EC2 instance creation, we need to create a key pair.
We will be creating a new key pair in our terraform directory. Run the following command:
ssh-keygen -t rsa -b 4096 -m pem -f terraform-project.pem && chmod 400 terraform-project.pem
*/

// Create a key pair named "terraform-project"
resource "aws_key_pair" "terraform-project" {
  key_name   = "terraform-project"
  public_key = file("terraform-project.pem.pub")
}

// Create EC2 instance
resource "aws_instance" "project-web" {
  count                  = var.settings.ec2.count
  ami                    = var.settings.ec2.ami
  instance_type          = var.settings.ec2.instance_type
  subnet_id              = aws_subnet.project-public-subnet[count.index].id
  vpc_security_group_ids = [aws_security_group.project-ec2-sg.id]
  key_name               = aws_key_pair.terraform-project.key_name
  tags = {
    Name = "project-web-${count.index}"
  }
}

// Create an Elastic IP
resource "aws_eip" "project-eip" {
  domain   = "vpc"
  instance = aws_instance.project-web[count.index].id
  count    = var.settings.ec2.count
}

// If you are running terraform on WSL, Run the below code before you SSH into your instance
// mv terraform-project.pem ~/
// chmod 400 ~/terraform-project.pem
// ssh -i "~/terraform-project.pem" ec2-user@$(terraform output -raw web_public_dns)

// Once in, run the following commands to install mysql client and connect to the database
// sudo dnf update
// wget https://dev.mysql.com/get/mysql80-community-release-el9-3.noarch.rpm
// sudo dnf install mysql-community-server
// sudo systemctl start mysqld
// sudo systemctl enable mysqld
// sudo systemctl status mysqld

// mysql -h <database-endpoint> -P <database-port> -u <db-username> -p
// enter password
// show DATABASES;

// terraform destroy -var-file="secrets.tfvars"