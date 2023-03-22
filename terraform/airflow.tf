resource "aws_vpc" "mwaa" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_mwaa" {
  count                   = 2
  cidr_block              = "10.0.${count.index}.0/24"
  vpc_id                  = aws_vpc.mwaa.id
  map_public_ip_on_launch = true
  availability_zone       = count.index % 2 == 0 ? "${var.region}a" : "${var.region}b"
}

resource "aws_subnet" "private_mwaa" {
  count                   = 2
  cidr_block              = "10.0.${count.index + 2}.0/24"
  vpc_id                  = aws_vpc.mwaa.id
  map_public_ip_on_launch = false
  availability_zone       = count.index % 2 == 0 ? "${var.region}a" : "${var.region}b"
}

resource "aws_eip" "this" {
  count = 2
  vpc   = true
}

resource "aws_nat_gateway" "this" {
  count         = 2
  allocation_id = aws_eip.this[count.index].id
  subnet_id     = aws_subnet.public_mwaa[count.index].id
}

resource "aws_internet_gateway" "mwaa" {
  vpc_id = aws_vpc.mwaa.id
}

resource "aws_route_table" "public_mwaa" {
  vpc_id = aws_vpc.mwaa.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mwaa.id
  }
}

resource "aws_route_table_association" "public_mwaa" {
  count          = 2
  route_table_id = aws_route_table.public_mwaa.id
  subnet_id      = aws_subnet.public_mwaa[count.index].id
}

resource "aws_route_table" "private_mwaa" {
  count  = length(aws_nat_gateway.this)
  vpc_id = aws_vpc.mwaa.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }
}

resource "aws_route_table_association" "private_mwaa" {
  count          = length(aws_subnet.private_mwaa)
  route_table_id = aws_route_table.private_mwaa[count.index].id
  subnet_id      = aws_subnet.private_mwaa[count.index].id
}

resource "aws_security_group" "mwaa" {
  vpc_id = aws_vpc.mwaa.id
  name   = "${var.name}-mwaa-no-ingress-sg"
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
}


resource "aws_iam_role" "mwaa" {
  name               = "${var.name}-mwaa-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy" "mwaa" {
  name   = "${var.name}-mwaa-execution-policy"
  policy = data.aws_iam_policy_document.mwaa.json
  role   = aws_iam_role.mwaa.id
}

data "aws_iam_policy_document" "assume" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    principals {
      identifiers = [
        "airflow-env.amazonaws.com",
        "airflow.amazonaws.com"
      ]
      type = "Service"
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

data "aws_iam_policy_document" "mwaa" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = [
      "airflow:PublishMetrics"
    ]
    resources = [
      "arn:aws:airflow:${var.region}:${data.aws_caller_identity.current.account_id}:environment/${var.name}-mwaa-environment"
    ]
  }
  statement {
    effect  = "Deny"
    actions = ["s3:ListAllMyBuckets"]
    resources = [
      aws_s3_bucket.mwaa.arn,
      "${aws_s3_bucket.mwaa.arn}/*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject*",
      "s3:GetBucket*",
      "s3:List*"
    ]
    resources = [
      aws_s3_bucket.mwaa.arn,
      "${aws_s3_bucket.mwaa.arn}/*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetAccountPublicAccessBlock"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:GetLogRecord",
      "logs:GetLogGroupFields",
      "logs:GetQueryResults"
    ]
    resources = [
      "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:airflow-${var.name}-mwaa-environment-*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups"
    ]
    resources = [
      "*"
    ]
  }
  statement {

    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
      "sqs:SendMessage"
    ]
    resources = [
      "arn:aws:sqs:${var.region}:*:airflow-celery-*"
    ]
  }
}

resource "aws_mwaa_environment" "this" {
  execution_role_arn = aws_iam_role.mwaa.arn
  name               = "${var.name}-mwaa-environment-2"
  max_workers        = 5
  min_workers        = 1
  airflow_version    = "2.4.3"

  source_bucket_arn = aws_s3_bucket.mwaa.arn
  dag_s3_path       = "dags/"

  network_configuration {
    security_group_ids = [aws_security_group.mwaa.id]
    subnet_ids         = aws_subnet.private_mwaa[*].id
  }
  webserver_access_mode = "PUBLIC_ONLY"
}
