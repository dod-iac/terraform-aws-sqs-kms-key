/**
 * ## Usage
 *
 * Creates a KMS Key for use with AWS SQS.
 *
 * ```hcl
 * module "sqs_kms_key" {
 *   source = "dod-iac/sqs-kms-key/aws"
 *
 *   name = format("alias/app-%s-sqs-%s", var.application, var.environment)
 *   description = format("A KMS key used to encrypt messages in SQS queues for %s:%s.", var.application, var.environment)
 *   principals = [aws_iam_user.main.arn]
 *   tags = {
 *     Application = var.application
 *     Environment = var.environment
 *     Automation  = "Terraform"
 *   }
 * }
 * ```
 *
 * ## Terraform Version
 *
 * Terraform 0.13. Pin module version to ~> 1.0.0 . Submit pull-requests to master branch.
 *
 * Terraform 0.11 and 0.12 are not supported.
 *
 * ## License
 *
 * This project constitutes a work of the United States Government and is not subject to domestic copyright protection under 17 USC § 105.  However, because the project utilizes code licensed from contributors and other third parties, it therefore is licensed under the MIT License.  See LICENSE file for more information.
 */

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

# https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-key-management.html
data "aws_iam_policy_document" "sqs" {
  policy_id = "key-policy-sqs"
  statement {
    sid = "Enable IAM User Permissions"
    actions = [
      "kms:*",
    ]
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        format(
          "arn:%s:iam::%s:root",
          data.aws_partition.current.partition,
          data.aws_caller_identity.current.account_id
        )
      ]
    }
    resources = ["*"]
  }
  statement {
    sid = "Allow services to use the key"
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = var.services
    }
    resources = ["*"]
  }
  dynamic "statement" {
    for_each = length(var.principals) > 0 ? [true] : []
    content {
      sid = "Allow principals to use the key"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.principals
      }
      resources = ["*"]
      condition {
        test     = "StringLike"
        variable = "kms:ViaService"
        values   = ["sqs.*.amazonaws.com"]
      }
    }
  }
}

resource "aws_kms_key" "sqs" {
  description             = var.description
  deletion_window_in_days = var.key_deletion_window_in_days
  enable_key_rotation     = "true"
  policy                  = data.aws_iam_policy_document.sqs.json
  tags                    = var.tags
}

resource "aws_kms_alias" "sqs" {
  name          = var.name
  target_key_id = aws_kms_key.sqs.key_id
}
