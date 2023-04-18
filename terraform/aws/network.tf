##################################
#          Networking            #
##################################

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${local.prefix}-main"
  }
}

resource "aws_security_group" "batch" {
  name        = "${local.prefix}-batch-sg"
  description = "Allow ECS tasks to reach out to internet"
  vpc_id      = aws_vpc.this.id

  egress {
    description = "Allow ECS tasks to talk to the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-batch-sg"
  }
}

resource "aws_security_group" "mwaa" {
  vpc_id = aws_vpc.this.id
  name   = "${local.prefix}-mwaa-no-ingress-sg"
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "${local.prefix}-mwaa-no-ingress-sg"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.prefix}-main"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.prefix}-public"
  }
}

resource "random_id" "public_subnet" {
  count       = 2
  byte_length = 3
}

resource "random_id" "private_subnet" {
  count       = 2
  byte_length = 3
}

resource "aws_eip" "this" {
  count = 2
  vpc   = true

  tags = {
    Name = "${local.prefix}-${data.aws_availability_zones.available.names[count.index]}-nat-${random_id.private_subnet[count.index].hex}"
  }
}

resource "aws_nat_gateway" "this" {
  count         = length(aws_subnet.public)
  allocation_id = aws_eip.this[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = {
    Name = "${local.prefix}-${data.aws_availability_zones.available.names[count.index]}-nat-${random_id.private_subnet[count.index].hex}"
  }
}

resource "aws_route_table" "private" {
  count  = length(aws_nat_gateway.this)
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }
  tags = {
    Name = "${local.prefix}-${data.aws_availability_zones.available.names[count.index]}-nat-${random_id.private_subnet[count.index].hex}"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.prefix}-${data.aws_availability_zones.available.names[count.index]}-public-${random_id.public_subnet[count.index].hex}"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.${count.index + length(aws_subnet.public)}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.prefix}-${data.aws_availability_zones.available.names[count.index]}-private-${random_id.private_subnet[count.index].hex}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  route_table_id = aws_route_table.private[count.index].id
  subnet_id      = aws_subnet.private[count.index].id
}
