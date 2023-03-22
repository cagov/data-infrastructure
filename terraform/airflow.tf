resource "aws_vpc" "mwaa" {
  cidr_block = "10.0.0.0/16"
}


module "airflow" {
  source  = "idealo/mwaa/aws"
  version = "v2.2.0"

  account_id       = data.aws_caller_identity.current.account_id
  environment_name = "${var.name}-mwaa-environment"
  airflow_version  = "2.4.3"
  region           = var.region

  create_networking_config = true
  vpc_id                   = aws_vpc.mwaa.id
  private_subnet_cidrs     = ["10.0.1.0/24", "10.0.2.0/24"] # depending on your vpc ip range
  public_subnet_cidrs      = ["10.0.3.0/24", "10.0.4.0/24"] # depending on your vpc ip range
  webserver_access_mode    = "PUBLIC_ONLY"

  source_bucket_arn = aws_s3_bucket.mwaa.arn
}
