locals {
  oidc_provider_hostpath = replace(var.oidc_provider_url, "https://", "")
  service_account_sub    = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "ExternalSecretsServiceAccountAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_hostpath}:sub"
      values   = [local.service_account_sub]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid    = "ReadApprovedCpemonSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]

    resources = var.secret_arns
  }

  dynamic "statement" {
    for_each = length(var.kms_key_arns) > 0 ? [1] : []

    content {
      sid    = "DecryptApprovedSecretsManagerKeys"
      effect = "Allow"

      actions = [
        "kms:Decrypt",
        "kms:DescribeKey",
      ]

      resources = var.kms_key_arns
    }
  }
}

resource "aws_iam_policy" "external_secrets" {
  name        = "${var.role_name}-policy"
  description = "Least-privilege Secrets Manager read policy for External Secrets Operator."
  policy      = data.aws_iam_policy_document.external_secrets.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.external_secrets.arn
}
