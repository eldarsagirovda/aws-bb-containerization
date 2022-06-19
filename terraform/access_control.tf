locals {
  eks_user_groups = [
    "game-team",
    "administrators",
    "eshop-team"
  ]
}

resource "aws_iam_role" "eks_access" {
  for_each = toset(local.eks_user_groups)

  name               = "${local.name}-eks-${each.value}-access"
  assume_role_policy = data.aws_iam_policy_document.account_assume_role_policy.json

  inline_policy {
    name   = "policy"
    policy = data.aws_iam_policy_document.inline_policy.json
  }

  tags = local.tags
}

data "aws_iam_policy_document" "inline_policy" {
  statement {
    actions   = ["eks:DescribeCluster"]
    resources = ["arn:aws:eks:${local.region}:${data.aws_caller_identity.current.account_id}:cluster/${local.name}"]
  }
}

data "aws_iam_policy_document" "account_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}