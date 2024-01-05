##################################
#          AWS Batch             #
##################################

data "aws_iam_policy_document" "aws_batch_service_policy" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["batch.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "aws_batch_service_role" {
  name               = "${local.prefix}-${var.region}-batch-service-role"
  assume_role_policy = data.aws_iam_policy_document.aws_batch_service_policy.json
}

resource "aws_iam_role_policy_attachment" "aws_batch_service_role" {
  role       = aws_iam_role.aws_batch_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_batch_compute_environment" "default" {
  compute_environment_name = "${local.prefix}-${var.region}-default"

  compute_resources {
    max_vcpus = 16

    security_group_ids = [
      aws_security_group.batch.id
    ]

    subnets = aws_subnet.public[*].id

    type = "FARGATE"
  }

  service_role = aws_iam_role.aws_batch_service_role.arn
  type         = "MANAGED"
  depends_on   = [aws_iam_role_policy_attachment.aws_batch_service_role]
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${local.prefix}-${var.region}-batch-exec-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_access_snowflake_loader" {
  for_each   = toset(local.jobs)
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.access_snowflake_loader[each.key].arn
}

resource "aws_iam_role" "batch_job_role" {
  name               = "${local.prefix}-${var.region}-batch-job-role"
  description        = "Role for AWS batch jobs"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "s3_scratch_policy_role_attachment" {
  role       = aws_iam_role.batch_job_role.name
  policy_arn = aws_iam_policy.s3_scratch_policy.arn
}

resource "aws_iam_role_policy_attachment" "dof_demographics_read_write_access" {
  role       = aws_iam_role.batch_job_role.name
  policy_arn = aws_iam_policy.dof_demographics_read_write_access.arn
}

resource "aws_batch_job_queue" "default" {
  name     = "${local.prefix}-${var.region}-default"
  state    = "ENABLED"
  priority = 1
  compute_environments = [
    aws_batch_compute_environment.default.arn,
  ]
}

resource "aws_batch_job_definition" "default" {
  for_each              = toset(local.jobs)
  name                  = "${local.prefix}-${var.region}-${each.key}"
  type                  = "container"
  platform_capabilities = ["FARGATE"]

  container_properties = jsonencode({
    command = ["echo", "$SNOWFLAKE_USER", "$SNOWFLAKE_ROLE"]
    image   = "${aws_ecr_repository.default.repository_url}:${each.key}"
    fargatePlatformConfiguration = {
      platformVersion = "LATEST"
    }
    resourceRequirements = [
      { type = "VCPU", value = "0.25" },
      { type = "MEMORY", value = "512" }
    ]
    # TODO: Figure out how to properly pass in a private key rather than a password.
    # Ran into some issues with properly encoding it as an environment variable.
    secrets = [
      for s in local.snowflake_data : {
        name      = "SNOWFLAKE_${upper(s)}",
        valueFrom = data.aws_secretsmanager_secret.snowflake_loader_secret[each.key].arn != null ? "${data.aws_secretsmanager_secret.snowflake_loader_secret[each.key].arn}:${s}::" : ""
      }
    ]
    networkConfiguration = {
      assignPublicIp : "ENABLED"
    },
    executionRoleArn = aws_iam_role.ecs_task_execution_role.arn
    jobRoleArn       = aws_iam_role.batch_job_role.arn
  })
}

data "aws_iam_policy_document" "batch_submit_policy_document" {
  statement {
    actions = [
      "batch:SubmitJob",
      "batch:CancelJob",
      "batch:ListJobs",
    ]
    resources = [
      "arn:aws:batch:${var.region}:${data.aws_caller_identity.current.account_id}:job-definition/${local.prefix}*",
      aws_batch_job_queue.default.arn,
    ]
  }
  statement {
    actions = [
      "batch:DescribeJobs",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "batch_submit_policy" {
  name        = "${local.prefix}-${var.region}-batch-submit-policy"
  description = "Policy allowing to submit batch jobs for ${local.prefix}"
  policy      = data.aws_iam_policy_document.batch_submit_policy_document.json
}
