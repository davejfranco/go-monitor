locals {
  debian12_ami_id = "ami-0735bf8e58d02fa57"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bird_key" {
  key_name   = "bird-key"
  public_key = tls_private_key.ssh_key.public_key_openssh

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/bird-key.pem"
  file_permission = "0400"
}

# Hub Router
resource "aws_security_group" "hub_router" {
  name        = "hub-router-sg"
  description = "Hub router security group"
  vpc_id      = module.vpc-hub.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Wireguard"
    from_port   = 51820
    to_port     = 51820
    protocol    = "tcp"
    cidr_blocks = [
      var.spoke_1_network_cidr,
      var.spoke_2_network_cidr
    ]
  }

  ingress {
    description = "Wireguard"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = [
      var.spoke_1_network_cidr,
      var.spoke_2_network_cidr
    ]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_instance" "hub_router" {
  ami           = local.debian12_ami_id
  instance_type = "t3.micro"
  subnet_id     = module.vpc-hub.public_subnets[0]
  key_name      = aws_key_pair.bird_key.key_name

  vpc_security_group_ids = [aws_security_group.hub_router.id]

  user_data = <<-EOF
    #!/bin/bash
    cat > /tmp/setup-router.sh <<'SCRIPT'
    ${file("${path.module}/config/setup-router.sh")}
    SCRIPT
    chmod +x /tmp/setup-router.sh
    /tmp/setup-router.sh hub-router
  EOF

  tags = {
    Name        = "hub-router"
    Terraform   = "true"
    Environment = "dev"
  }
}

output "hub_router_public_ip" {
  value = aws_instance.hub_router.public_ip
}

# Spoke 1 Router
resource "aws_security_group" "spoke_1_router" {
  name        = "spoke-1-router-sg"
  description = "Spoke 1 router security group"
  vpc_id      = module.vpc-spoke-1.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Wireguard"
    from_port   = 51820
    to_port     = 51820
    protocol    = "tcp"
    cidr_blocks = [
      var.hub_network_cidr
    ]
  }

  ingress {
    description = "Wireguard"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = [
      var.hub_network_cidr
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_instance" "spoke_1_router" {
  ami           = local.debian12_ami_id
  instance_type = "t3.micro"
  subnet_id     = module.vpc-spoke-1.public_subnets[0]
  key_name      = aws_key_pair.bird_key.key_name

  vpc_security_group_ids = [aws_security_group.spoke_1_router.id]

  user_data = <<-EOF
    #!/bin/bash
    cat > /tmp/setup-router.sh <<'SCRIPT'
    ${file("${path.module}/config/setup-router.sh")}
    SCRIPT
    chmod +x /tmp/setup-router.sh
    /tmp/setup-router.sh spoke-1-router
  EOF

  tags = {
    Name        = "spoke-1-router"
    Terraform   = "true"
    Environment = "dev"
  }
}

output "spoke_1_router_public_ip" {
  value = aws_instance.spoke_1_router.public_ip
}

# Spoke 2 Router
resource "aws_security_group" "spoke_2_router" {
  name        = "spoke-2-router-sg"
  description = "Spoke 2 router security group"
  vpc_id      = module.vpc-spoke-2.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Wireguard"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = [
      var.hub_network_cidr
    ]
  }
  
  ingress {
    description = "Wireguard"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = [
      var.hub_network_cidr
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_instance" "spoke_2_router" {
  ami           = local.debian12_ami_id
  instance_type = "t3.micro"
  subnet_id     = module.vpc-spoke-2.public_subnets[0]
  key_name      = aws_key_pair.bird_key.key_name

  vpc_security_group_ids = [aws_security_group.spoke_2_router.id]

  user_data = <<-EOF
    #!/bin/bash
    cat > /tmp/setup-router.sh <<'SCRIPT'
    ${file("${path.module}/config/setup-router.sh")}
    SCRIPT
    chmod +x /tmp/setup-router.sh
    /tmp/setup-router.sh spoke-2-router
  EOF

  tags = {
    Name        = "spoke-2-router"
    Terraform   = "true"
    Environment = "dev"
  }
}

output "spoke_2_router_public_ip" {
  value = aws_instance.spoke_2_router.public_ip
}
