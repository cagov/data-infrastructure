##################################
#          PrivateLink           #
##################################

# Resolve RDS endpoint to IP at apply time.
# This is a short term resolution: IP can change after maintenance/failover.
# If that happens, re-run terraform apply to re-register the new IP with the NLB target group.
# AWS has a couple of possible ways to make this more robust:
#
#   1. Use RDS proxy for a more stable IP
#   2. Set up a lambda to auto-refresh the target group for the NLB.
#
# Both of these increase the complexity of this POC, so keeping it simple for now,
# knowing that this is a more fragile setup.
data "dns_a_record_set" "rds" {
  count = var.enable_rds ? 1 : 0
  host  = aws_db_instance.sqlserver[0].address
}

resource "aws_security_group" "privatelink_nlb" {
  count       = var.enable_rds ? 1 : 0
  name        = "${local.prefix}-privatelink-nlb-sg"
  description = "PrivateLink NLB for RDS SQL Server"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "From PrivateLink endpoints over 1433"
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Forward to resources in the private subnet (primarily RDS SQL Server)"
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = aws_subnet.private[*].cidr_block
  }

  tags = {
    Name = "${local.prefix}-privatelink-nlb-sg"
  }
}

resource "aws_lb" "privatelink" {
  count              = var.enable_rds ? 1 : 0
  name               = "${local.prefix}-privatelink-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = aws_subnet.private[*].id
  security_groups    = [aws_security_group.privatelink_nlb[0].id]

  tags = {
    Name = "${local.prefix}-privatelink-nlb"
  }
}

resource "aws_lb_target_group" "rds" {
  count       = var.enable_rds ? 1 : 0
  name        = "${local.prefix}-rds-tg"
  port        = 1433
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = aws_vpc.this.id

  health_check {
    protocol = "TCP"
    port     = 1433
  }
}

resource "aws_lb_target_group_attachment" "rds" {
  count            = var.enable_rds ? 1 : 0
  target_group_arn = aws_lb_target_group.rds[0].arn
  target_id        = data.dns_a_record_set.rds[0].addrs[0]
  port             = 1433
}

resource "aws_lb_listener" "rds" {
  count             = var.enable_rds ? 1 : 0
  load_balancer_arn = aws_lb.privatelink[0].arn
  port              = 1433
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rds[0].arn
  }
}

resource "aws_vpc_endpoint_service" "rds" {
  count                      = var.enable_rds ? 1 : 0
  network_load_balancer_arns = [aws_lb.privatelink[0].arn]
  acceptance_required        = true

  tags = {
    Name = "${local.prefix}-rds-endpoint-service"
  }
}

resource "aws_vpc_endpoint_service_allowed_principal" "consumers" {
  for_each = var.enable_rds ? toset(var.privatelink_allowed_principals) : toset([])

  vpc_endpoint_service_id = aws_vpc_endpoint_service.rds[0].id
  principal_arn           = each.value
}
