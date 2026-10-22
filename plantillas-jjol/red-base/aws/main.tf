locals {
  tags  = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  base  = "${var.name}-${var.environment}"
  zones = slice(data.aws_availability_zones.available.names, 0, var.zones)
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "vpc-${local.base}" }
}

# El security group por defecto queda sin reglas: nada lo usa por accidente.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "default-sin-reglas" }
}

resource "aws_subnet" "public" {
  count                   = var.zones
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr, 4, count.index)
  availability_zone       = local.zones[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "snet-publica-${local.zones[count.index]}", tier = "public" }
}

resource "aws_subnet" "private" {
  count                   = var.zones
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr, 4, count.index + 8)
  availability_zone       = local.zones[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "snet-privada-${local.zones[count.index]}", tier = "private" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "igw-${local.base}" }
}

resource "aws_eip" "nat" {
  count  = var.nat ? var.zones : 0
  domain = "vpc"
  tags   = { Name = "eip-nat-${local.zones[count.index]}" }
}

resource "aws_nat_gateway" "this" {
  count         = var.nat ? var.zones : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "nat-${local.zones[count.index]}" }
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "rt-publica-${local.base}" }
}

resource "aws_route_table_association" "public" {
  count          = var.zones
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = var.zones
  vpc_id = aws_vpc.this.id
  dynamic "route" {
    for_each = var.nat ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[count.index].id
    }
  }
  tags = { Name = "rt-privada-${local.zones[count.index]}" }
}

resource "aws_route_table_association" "private" {
  count          = var.zones
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Security group de aplicaciones: HTTPS solo desde la propia VPC.
resource "aws_security_group" "app" {
  name        = "sg-app-${local.base}"
  description = "Aplicaciones: HTTPS desde la VPC"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS desde la VPC"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [var.cidr]
  }

  egress {
    description = "Salida"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-app-${local.base}" }
}

# Flow logs de la VPC a CloudWatch Logs.
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/plantillas-jjol/vpc/${local.base}"
  retention_in_days = var.flow_logs_retention_days
}

data "aws_iam_policy_document" "flow_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "flow" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = ["${aws_cloudwatch_log_group.flow.arn}:*"]
  }
}

resource "aws_iam_role" "flow" {
  name               = "flow-logs-${local.base}"
  assume_role_policy = data.aws_iam_policy_document.flow_assume.json
}

resource "aws_iam_role_policy" "flow" {
  name   = "flow-logs"
  role   = aws_iam_role.flow.id
  policy = data.aws_iam_policy_document.flow.json
}

resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow.arn
  iam_role_arn    = aws_iam_role.flow.arn
}
