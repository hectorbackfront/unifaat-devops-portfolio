###############################################################################
# GROUPS - separação de responsabilidades
###############################################################################
# Nota: aws_iam_group não suporta o argumento "tags" — é uma limitação da API
# do IAM, não do Terraform. A rastreabilidade dos groups é garantida pelo
# prefixo de RA no nome e pelas policies tagueadas anexadas a eles.

resource "aws_iam_group" "developers" {
  name = "${local.prefix}-developers"
}

resource "aws_iam_group" "platform_eng" {
  name = "${local.prefix}-platform-eng"
}

###############################################################################
# USERS
###############################################################################

resource "aws_iam_user" "juliana_dev" {
  name          = "${var.ra}-juliana-dev"
  force_destroy = true

  tags = merge(local.common_tags, {
    Name  = "${var.ra}-juliana-dev"
    Cargo = "Developer"
  })
}

resource "aws_iam_user" "rafael_platform" {
  name          = "${var.ra}-rafael-platform"
  force_destroy = true

  tags = merge(local.common_tags, {
    Name  = "${var.ra}-rafael-platform"
    Cargo = "Platform Engineer"
  })
}

resource "aws_iam_user" "lucas_intern" {
  name          = "${var.ra}-lucas-intern"
  force_destroy = true

  tags = merge(local.common_tags, {
    Name  = "${var.ra}-lucas-intern"
    Cargo = "Intern"
  })
}

###############################################################################
# MEMBERSHIPS
###############################################################################
# Usamos aws_iam_user_group_membership (não-exclusivo) porque o rafael
# pertence a dois groups ao mesmo tempo. O recurso aws_iam_group_membership
# seria exclusivo e removeria membros não declarados nele.

resource "aws_iam_user_group_membership" "juliana_dev" {
  user   = aws_iam_user.juliana_dev.name
  groups = [aws_iam_group.developers.name]
}

resource "aws_iam_user_group_membership" "rafael_platform" {
  user = aws_iam_user.rafael_platform.name
  groups = [
    aws_iam_group.developers.name,
    aws_iam_group.platform_eng.name,
  ]
}

resource "aws_iam_user_group_membership" "lucas_intern" {
  user   = aws_iam_user.lucas_intern.name
  groups = [aws_iam_group.developers.name]
}
