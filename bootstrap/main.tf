locals {
  repo_name = "memex-suite"
}

# ── SAM artifacts bucket ───────────────────────────────────────────────────────
# SAM uploads built Lambda packages here before CloudFormation deploys them.
# --resolve-s3 auto-creates a bucket but it uses a random name; this gives us
# a named, version-enabled bucket with explicit encryption and access controls.

resource "aws_s3_bucket" "sam_artifacts" {
  bucket = var.sam_bucket_name
}

resource "aws_s3_bucket_versioning" "sam_artifacts" {
  bucket = aws_s3_bucket.sam_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sam_artifacts" {
  bucket = aws_s3_bucket.sam_artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "sam_artifacts" {
  bucket                  = aws_s3_bucket.sam_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── GitHub Actions OIDC provider ───────────────────────────────────────────────
# Only one OIDC provider per URL per account. If platform-bootstrap already
# created this provider, import it: terraform import aws_iam_openid_connect_provider.github_actions <arn>
# Then it will be managed here without re-creating.

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# ── IAM deploy role ────────────────────────────────────────────────────────────
# Assumed by GitHub Actions on push to main. Scoped to memex-suite resources
# (prefix memex-*) where possible; broader where AWS does not support resource-
# level restrictions (e.g. CloudFormation describe, API Gateway).

resource "aws_iam_role" "github_actions_deploy" {
  name        = "memex-suite-github-actions-deploy"
  description = "Assumed by GitHub Actions to deploy memex-suite via SAM"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubActionsOIDC"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${local.repo_name}:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "deploy" {
  name        = "memex-suite-sam-deploy"
  description = "Allows SAM to deploy and manage memex-suite Lambda infrastructure"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SAMArtifactsBucket"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.sam_artifacts.arn,
          "${aws_s3_bucket.sam_artifacts.arn}/*",
        ]
      },
      {
        Sid    = "CloudFormation"
        Effect = "Allow"
        Action = [
          "cloudformation:CreateStack",
          "cloudformation:UpdateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:DescribeStackEvents",
          "cloudformation:DescribeStackResources",
          "cloudformation:GetTemplate",
          "cloudformation:ValidateTemplate",
          "cloudformation:CreateChangeSet",
          "cloudformation:ExecuteChangeSet",
          "cloudformation:DescribeChangeSet",
          "cloudformation:DeleteChangeSet",
          "cloudformation:ListStacks",
          "cloudformation:ListStackResources",
        ]
        # SAM creates transform stacks with generated names — must allow wildcard here
        Resource = "*"
      },
      {
        Sid    = "Lambda"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:TagResource",
          "lambda:ListFunctions",
          "lambda:PublishVersion",
          "lambda:CreateAlias",
          "lambda:UpdateAlias",
          "lambda:DeleteAlias",
          "lambda:ListEventSourceMappings",
          "lambda:CreateEventSourceMapping",
          "lambda:UpdateEventSourceMapping",
          "lambda:DeleteEventSourceMapping",
        ]
        Resource = "arn:aws:lambda:*:${var.aws_account_id}:function:memex-*"
      },
      {
        Sid    = "IAMExecutionRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:TagRole",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:ListPolicyVersions",
          "iam:TagPolicy",
        ]
        Resource = [
          "arn:aws:iam::${var.aws_account_id}:role/memex-*",
          "arn:aws:iam::${var.aws_account_id}:policy/memex-*",
        ]
      },
      {
        # PassRole allows CloudFormation to assign execution roles to Lambda functions
        Sid      = "IAMPassRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:aws:iam::${var.aws_account_id}:role/memex-*"
      },
      {
        Sid    = "APIGateway"
        Effect = "Allow"
        Action = ["apigateway:*"]
        # API Gateway resource ARNs don't follow a predictable prefix
        Resource = "arn:aws:apigateway:${var.aws_region}::*"
      },
      {
        Sid    = "SQS"
        Effect = "Allow"
        Action = ["sqs:*"]
        Resource = "arn:aws:sqs:*:${var.aws_account_id}:memex-*"
      },
      {
        Sid    = "EventBridge"
        Effect = "Allow"
        Action = ["events:*"]
        Resource = [
          "arn:aws:events:*:${var.aws_account_id}:rule/memex-*",
          "arn:aws:events:*:${var.aws_account_id}:event-bus/memex-*",
        ]
      },
      {
        Sid    = "StepFunctions"
        Effect = "Allow"
        Action = ["states:*"]
        Resource = "arn:aws:states:*:${var.aws_account_id}:*memex*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogDelivery",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DeleteLogGroup",
          "logs:TagResource",
        ]
        Resource = "arn:aws:logs:*:${var.aws_account_id}:log-group:/aws/lambda/memex-*"
      },
      {
        Sid    = "SSMParameters"
        Effect = "Allow"
        Action = ["ssm:GetParameter", "ssm:PutParameter", "ssm:DeleteParameter"]
        Resource = "arn:aws:ssm:*:${var.aws_account_id}:parameter/memex/*"
      },
      {
        Sid      = "STSCallerIdentity"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "deploy" {
  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = aws_iam_policy.deploy.arn
}
