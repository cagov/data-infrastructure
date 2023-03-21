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
  name               = "aws_batch_service_role"
  assume_role_policy = data.aws_iam_policy_document.aws_batch_service_policy.json
}

resource "aws_iam_role_policy_attachment" "aws_batch_service_role" {
  role       = aws_iam_role.aws_batch_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_batch_compute_environment" "batch_env" {
  compute_environment_name = "${var.name}-batch-env"

  compute_resources {
    max_vcpus = 16

    security_group_ids = [
      aws_security_group.sg.id
    ]

    subnets = aws_subnet.public[*].id

    type = "FARGATE"
  }

  service_role = aws_iam_role.aws_batch_service_role.arn
  type         = "MANAGED"
  depends_on   = [aws_iam_role_policy_attachment.aws_batch_service_role]
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.name}-batch-exec-role"
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

resource "aws_iam_role" "batch_job_role" {
  name               = "${var.name}-batch-job-role"
  description        = "Role for AWS batch jobs"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "s3_scratch_policy_role_attachment" {
  role       = aws_iam_role.batch_job_role.name
  policy_arn = aws_iam_policy.s3_scratch_policy.arn
}

resource "aws_batch_job_queue" "batch_queue" {
  name     = "${var.name}-batch-job-queue"
  state    = "ENABLED"
  priority = 1
  compute_environments = [
    aws_batch_compute_environment.batch_env.arn,
  ]
}

resource "aws_batch_job_definition" "batch_job_def" {
  name = "${var.name}-batch-job-definition"
  type = "container"
  platform_capabilities = [
    "FARGATE",
  ]

  container_properties = jsonencode({
    command = ["python", "-m", "jobs.test"]
    image   = "${aws_ecr_repository.main_ecr.repository_url}:latest"
    fargatePlatformConfiguration = {
      platformVersion = "LATEST"
    }
    resourceRequirements = [
      { type = "VCPU", value = "0.25" },
      { type = "MEMORY", value = "512" }
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
      "arn:aws:batch:${var.region}:${data.aws_caller_identity.current.account_id}:job-definition/${var.name}*",
      aws_batch_job_queue.batch_queue.arn,
    ]
  }
}

resource "aws_iam_policy" "batch_submit_policy" {
  name        = "${var.name}-batch-submit-policy"
  description = "Policy allowing to submit batch jobs for ${var.name}"
  policy      = data.aws_iam_policy_document.batch_submit_policy_document.json
}
