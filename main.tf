#create VPC
resource "aws_vpc" "KCVPC" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "KCVPC"
  }
}

# Create a public subnet
resource "aws_subnet" "KC_publicSubnet" {
  vpc_id     = aws_vpc.KCVPC.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "KC_publicSubnet"
  }
}

#create a private subnet
resource "aws_subnet" "KC_privateSubnet" {
  vpc_id     = aws_vpc.KCVPC.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "KC_privateSubnet"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "KC_IGW" {
  vpc_id = aws_vpc.KCVPC.id

  tags = {
    Name = "KC_IGW"
  }
}

# Create a route table for the public subnet
resource "aws_route_table" "KC_public_route_table" {
  vpc_id = aws_vpc.KCVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.KC_IGW.id
    }

    tags = {
      Name = "KC_public_route_table"
    }
}
# Associate the public subnet with the route table  
resource "aws_route_table_association" "KC_public_association" {
  subnet_id      = aws_subnet.KC_publicSubnet.id
  route_table_id = aws_route_table.KC_public_route_table.id
}

#create a route table for the private subnet
resource "aws_route_table" "KC_private_route_table" {
  vpc_id = aws_vpc.KCVPC.id

  tags = {
    Name = "KC_private_route_table"
  }
}

# Associate the private subnet with the route table
resource "aws_route_table_association" "KC_private_association" {
  subnet_id      = aws_subnet.KC_privateSubnet.id
  route_table_id = aws_route_table.KC_private_route_table.id
}

# create an Elastic IP for the NAT Gateway
resource "aws_eip" "KC_NAT_EIP" {
  #instance = aws_instance.KC_NAT_GW.id
  domain = "vpc"

#create an Elastic IP for the NAT Gateway
  tags = {
    Name = "KC_NAT_EIP"
  }
}

# Create a NAT Gateway in the public subnet
resource "aws_nat_gateway" "KC_NAT_GW" {
  allocation_id = aws_eip.KC_NAT_EIP.id
  subnet_id = aws_subnet.KC_publicSubnet.id

  tags = {
    Name = "KC_NAT_GW"
  }
}   

# to ensure proper ordering, it is recommended to add explicit dependency

# Update the private route table to route traffic through the NAT Gateway
resource "aws_route" "KC_private_nat_route" {
  route_table_id         = aws_route_table.KC_private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.KC_NAT_GW.id 
}

# Create a security group for the public Instances
resource "aws_security_group" "Public_SG" {
  name        = "Public_SG"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.KCVPC.id

  tags = {
    Name = "Public_SG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_HTTPS" {
  security_group_id = aws_security_group.Public_SG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
} 

resource "aws_vpc_security_group_ingress_rule" "allow_HTTP" {
  security_group_id = aws_security_group.Public_SG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
} 
resource "aws_vpc_security_group_ingress_rule" "allow_SSH" {
  security_group_id = aws_security_group.Public_SG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
} 

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.Public_SG.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Create a security group for the Private Instances
resource "aws_security_group" "Private_SG" {
  name        = "Private_SG"
  description = "Allow specific inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.KCVPC.id

  tags = {
    Name = "Private_SG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_Postgresql" {
  security_group_id = aws_security_group.Private_SG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 5432
  ip_protocol       = "tcp"
  to_port           = 5432  
} 


resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_out" {
  security_group_id = aws_security_group.Private_SG.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# create a keypair for the instance
resource "aws_key_pair" "KC_keypair2" {
  key_name   = "KC_keypair2"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKa4PGt5aD9rUy3SyxNrbkdYWGjxFcoeyKZXSH8iCWme olami@Olamide" # Ensure you have a valid public key file
}


# create an EC2 instance in the public subnet
resource "aws_instance" "Webserver" {
  ami           = "ami-084568db4383264d4" # Replace with a valid AMI ID
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.KC_publicSubnet.id
  security_groups = [aws_security_group.Public_SG.id]
    associate_public_ip_address = true  

  user_data = <<-EOF
}
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from Webserver</h1>" > /var/www/html/index.html
              EOF   
    availability_zone = "us-east-1a"
    key_name = "KC_keypair2"

  tags = {
    Name = "Webserver"
  }
}

# create an EC2 instance in the private subnet
resource "aws_instance" "PrivateInstance" {
  ami           = "ami-084568db4383264d4"  
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.KC_privateSubnet.id
  vpc_security_group_ids = [aws_security_group.Private_SG.id]
  user_data     = file("scripts/postgresql.sh")
  tags = {
    Name = "PrivateInstance"
  }
}
