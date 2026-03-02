##################################
#        RDS SQL Server          #
##################################

resource "aws_db_subnet_group" "rds_sqlserver" {
  count      = var.enable_rds ? 1 : 0
  name       = "${local.prefix}-rds-sqlserver-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_cloudwatch_log_group" "rds_sqlserver_error_logs" {
  count             = var.enable_rds ? 1 : 0
  name              = "/aws/rds/instance/${local.prefix}-sqlserver/error"
  retention_in_days = 7
}

resource "aws_db_instance" "sqlserver" {
  count = var.enable_rds ? 1 : 0

  identifier = "${local.prefix}-sqlserver"
  engine     = "sqlserver-se"
  # SQL Server 2019 Standard Edition (required for CDC)
  engine_version = "15.00.4385.2.v1"

  instance_class    = "db.m5.large"
  license_model     = "license-included"
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  username                    = "admin"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.rds_sqlserver[0].name
  vpc_security_group_ids = [aws_security_group.rds_sqlserver[0].id]

  # Backup configuration
  backup_retention_period = 7

  # Monitoring and logs
  enabled_cloudwatch_logs_exports = ["error"]

  # Skip final snapshot for dev environment
  skip_final_snapshot = true

  tags = {
    Name = "${local.prefix}-sqlserver"
  }

  depends_on = [aws_cloudwatch_log_group.rds_sqlserver_error_logs]
}
