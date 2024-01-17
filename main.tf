terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    github = {
      source = "integrations/github"

    }
  }
}

data "github_repository" "myrepo" {
  name = "RealEstate-Project"

}

data "github_branch" "main" {
  branch     = "main"
  repository = data.github_repository.myrepo.name
}

resource "aws_iam_role" "aws_access" {
  name = "awsrole-${var.user}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess", "arn:aws:iam::aws:policy/AmazonEC2FullAccess", "arn:aws:iam::aws:policy/IAMFullAccess", "arn:aws:iam::aws:policy/AmazonS3FullAccess"]
}

resource "aws_iam_instance_profile" "ec2-profile" {
  name = "realestate-project-profile-${var.user}"
  role = aws_iam_role.aws_access.name
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
}


# START----------Create VPC, Subnet Group, Public Route Table, Route Table Association and Internet Gateway---------- 

# https://medium.com/@mitesh_shamra/manage-aws-vpc-with-terraform-d477d0b5c9c5 
# https://github.com/elastic/examples/blob/master/Cloud%20Enterprise/Getting%20Started%20Examples/aws/terraform/variables.tf

resource "aws_vpc" "my_vpc" {
  cidr_block           = var.cidr_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name       = var.project_name
    managed-by = "terraform"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.cidr_subnet[0]
  availability_zone = "${var.aws_region}${element(var.zones, 0)}"
  map_public_ip_on_launch = true
  tags = {
    Name       = "${var.subnet_name}-public-1"
    managed-by = "terraform"
    Type = "public"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.cidr_subnet[1]
  availability_zone = "${var.aws_region}${element(var.zones, 1)}"
  map_public_ip_on_launch = true
  tags = {
    Name       = "${var.subnet_name}-public-2"
    managed-by = "terraform"
    Type = "public"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.cidr_subnet_2[0]
  availability_zone = "${var.aws_region}${element(var.zones, 0)}"
  map_public_ip_on_launch = true
  tags = {
    Name       = "${var.subnet_name}-private-1"
    managed-by = "terraform"
    Type = "private"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.cidr_subnet_2[1]
  availability_zone = "${var.aws_region}${element(var.zones, 1)}"
  map_public_ip_on_launch = true
  tags = {
    Name       = "${var.subnet_name}-private-2"
    managed-by = "terraform"
    Type = "private"
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name       = var.project_name
    managed-by = "terraform"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
  tags = {
    Name       = "${var.project_name}-Public-RT"
    managed-by = "terraform"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name       = "${var.project_name}-Private-RT"
    managed-by = "terraform"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

# END----------Create VPC, Subnet Group, Public Route Table, Route Table Association and Internet Gateway---------- 


# START----------Launch Intances---------- 

resource "aws_instance" "realestate-project-ec2-instance" {
  ami           = data.aws_ami.al2023.id
  instance_type = var.instance_type
  key_name      = var.mykeypair
  subnet_id     = aws_subnet.public_subnet_1.id
  vpc_security_group_ids      = [aws_security_group.realestate_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2-profile.name
  associate_public_ip_address = true
  tags = {
    Name = "${var.tag[1]}"
  }
  user_data = <<-EOF
          #! /bin/bash
          yum update -y
          yum install git -y
          cd /home/ec2-user
          EOF
}

# TOKEN="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
# sudo git clone https://Klcknn:$TOKEN@github.com/Klcknn/${data.github_repository.myrepo.name}.git
# chown -R ec2-user:ec2-user ${data.github_repository.myrepo.name}

# END----------Launch Intances---------- 

# START----------Security Groups---------- 

resource "aws_security_group" "realestate_sg" {
  name        = "${var.realestate-sg}-${var.user}"
  description = "Bluecar security group with dynamic ports"
  vpc_id      = aws_vpc.my_vpc.id
  tags = {
    Name = var.realestate-sg
  }

  dynamic "ingress" {
    for_each = var.allowed_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# END----------Security Groups---------- 


resource "aws_instance" "control_node" {
  ami                    = var.myami
  instance_type          = var.instance_type
  count                  = var.num
  key_name               = var.mykeypair
  subnet_id              = aws_subnet.public_subnet_2.id
  vpc_security_group_ids = [aws_security_group.tf-sec-gr.id]
  tags = {
    Name = "${var.tag[0]}"
  }
}

resource "aws_security_group" "tf-sec-gr" {
  name   = "ansible-lesson3-sec-gr-${var.user}"
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "ansible-session3-sec-gr-${var.user}"
  }

  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "null_resource" "config" {
  depends_on = [aws_instance.control_node[0]]
  connection {
    host = aws_instance.control_node[0].public_ip
    type = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/${var.mykeypair}.pem")

  }

  provisioner "file" {
    source      = "./ansible.cfg"
    destination = "/home/ec2-user/ansible.cfg"
 
  }

  provisioner "file" {
    source      = "~/.ssh/${var.mykeypair}.pem"
    destination = "/home/ec2-user/${var.mykeypair}.pem"
  }

  provisioner "file" {
    source      = "./userdata.yaml"
    destination = "/home/ec2-user/userdata.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname Control-Node",
      "sudo dnf update -y",
      "curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py",
      "python3 get-pip.py --user",
      "pip3 install --user ansible",
      "echo [webservers] >> inventory.txt",
      "echo node1 ansible_host=${aws_instance.realestate-project-ec2-instance.private_ip} ansible_ssh_private_key_file=/home/ec2-user/${var.mykeypair}.pem ansible_user=ec2-user >> inventory.txt",
      "chmod 400 ${var.mykeypair}.pem",
      "ansible-playbook -i inventory.txt userdata.yaml"
    ]
  }

}

# START----------OUTPUTS---------- 

output "RealEState-Project-EC2-Instance_Public-IP-Address" {
  value = "http://${aws_instance.realestate-project-ec2-instance.public_ip}"
}

output "RealEState-Project-EC2-Instance_Jenkins-Server" {
  value = "http://${aws_instance.realestate-project-ec2-instance.public_ip}:8080"
}

output "RealEState-Project-EC2-Instance-Public-DNS-Address" {
  value = "http://${aws_instance.realestate-project-ec2-instance.public_dns}"
}

output "ssh-connection" {
  value = "ssh -i ~/.ssh/${var.mykeypair}.pem ec2-user@${aws_instance.realestate-project-ec2-instance.public_dns}"
}

output "controlnodeip" {
  value = aws_instance.control_node[0].public_ip
}

output "control_node_ssh-connection" {
  value = "ssh -i ~/.ssh/${var.mykeypair}.pem ec2-user@${aws_instance.control_node[0].public_dns}"
}

# END----------OUTPUTS---------- 


