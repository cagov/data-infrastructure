resource "aws_iam_role" "mwaa" {
  name               = "${var.name}-mwaa-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_policy" "mwaa" {
  name   = "${var.name}-mwaa-execution-policy"
  policy = data.aws_iam_policy_document.mwaa.json
}

resource "aws_iam_role_policy_attachment" "mwaa_execution_role" {
  role       = aws_iam_role.mwaa.name
  policy_arn = aws_iam_policy.mwaa.arn
}

resource "aws_iam_role_policy_attachment" "mwaa_batch_submit_role" {
  role       = aws_iam_role.mwaa.name
  policy_arn = aws_iam_policy.batch_submit_policy.arn
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
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:Encrypt"
    ]
    resources     = []
    not_resources = ["arn:aws:kms:*:${data.aws_caller_identity.current.account_id}:key/*"]
    condition {
      test = "StringLike"
      values = [
        "sqs.${var.region}.amazonaws.com"
      ]
      variable = "kms:ViaService"
    }
  }
}

resource "aws_mwaa_environment" "this" {
  execution_role_arn = aws_iam_role.mwaa.arn
  name               = "${var.name}-mwaa-environment"
  schedulers         = 2
  max_workers        = 5
  min_workers        = 1
  airflow_version    = "2.4.3"

  source_bucket_arn = aws_s3_bucket.mwaa.arn
  dag_s3_path       = "dags/"

  network_configuration {
    security_group_ids = [aws_security_group.mwaa.id]
    subnet_ids         = aws_subnet.private[*].id
  }
  webserver_access_mode = "PUBLIC_ONLY"
}
