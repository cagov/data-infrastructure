##################################
#        Terraform Setup         #
##################################

terraform {
  backend "s3" {
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.56.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Owner   = "CalData-DSE"
      Project = var.name
    }
  }
}

##################################
#       Container registry       #
##################################

resource "aws_ecr_repository" "main_ecr" {
  name                 = "${var.name}-ecr-${var.region}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

data "aws_iam_policy_document" "main_ecr_policy_document" {
  # Policy from https://github.com/aws-actions/amazon-ecr-login#permissions
  statement {
    actions = [
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.main_ecr.arn]
  }
  statement {
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "batch_submit_policy_document" {
  statement {
    actions = [
      "batch:SubmitJob",
      "batch:CancelJob",
      "batch:ListJobs",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "main_ecr_policy" {
  name        = "${var.name}-ecr-push-policy"
  description = "Policy allowing pushing to the main ecr repository for ${var.name}"
  policy      = data.aws_iam_policy_document.main_ecr_policy_document.json
}

resource "aws_iam_policy" "batch_submit_policy" {
  name        = "${var.name}-batch-submit-policy"
  description = "Policy allowing to submit batch jobs for ${var.name}"
  policy      = data.aws_iam_policy_document.batch_submit_policy_document.json
}

resource "aws_iam_user" "cd_bot" {
  name = "${var.name}-cd-bot"
}

resource "aws_iam_user_policy_attachment" "ecr_cd_bot_policy_attachment" {
  user       = aws_iam_user.cd_bot.name
  policy_arn = aws_iam_policy.main_ecr_policy.arn
}

resource "aws_iam_user_policy_attachment" "batch_cd_bot_policy_attachment" {
  user       = aws_iam_user.cd_bot.name
  policy_arn = aws_iam_policy.batch_submit_policy.arn
}

##################################
#          Networking            #
##################################

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_security_group" "sg" {
  name        = "aws_batch_compute_environment_security_group"
  description = "Allow ECS tasks to reach out to internet"
  vpc_id      = aws_vpc.this.id

  egress {
    description = "Allow ECS tasks to talk to the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route" "public" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = false
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

##################################
#             S3                 #
##################################

resource "aws_s3_bucket" "scratch" {
  bucket = "${var.name}-scratch"
}

data "aws_iam_policy_document" "s3_scratch_policy_document" {
  statement {
    actions = [
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.scratch.arn]
  }
  statement {
    actions = [
      "s3:ListBucket",
      "s3:*Object",
    ]
    resources = ["${aws_s3_bucket.scratch.arn}/*"]
  }
}

resource "aws_iam_policy" "s3_scratch_policy" {
  name        = "${var.name}-s3-scratch-policy"
  description = "Policy allowing read/write for s3 scratch bucket"
  policy      = data.aws_iam_policy_document.s3_scratch_policy_document.json
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

    subnets = [
      aws_subnet.public.id
    ]

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
