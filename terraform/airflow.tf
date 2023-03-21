module "airflow" {
  source  = "idealo/mwaa/aws"
  version = "v2.2.0"

  account_id       = data.aws_caller_identity.current.account_id
  environment_name = "${var.name}-mwaa-environment"
  region           = var.region

  create_networking_config = false
  vpc_id                   = aws_vpc.this.id
  private_subnet_ids       = aws_subnet.private[*].id

  source_bucket_arn = aws_s3_bucket.mwaa.arn
}
