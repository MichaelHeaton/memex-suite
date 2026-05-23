output "deploy_role_arn" {
  description = "ARN to set as AWS_DEPLOY_ROLE_ARN in GitHub Actions secrets"
  value       = aws_iam_role.github_actions_deploy.arn
}

output "sam_artifacts_bucket" {
  description = "S3 bucket name for SAM -- pass via samconfig.toml or --s3-bucket flag"
  value       = aws_s3_bucket.sam_artifacts.id
}

output "oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}
