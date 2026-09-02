###############################################################################
# GROUPS
###############################################################################

output "iam_groups" {
  description = "Nomes e ARNs dos groups criados"
  value = {
    developers = {
      name = aws_iam_group.developers.name
      arn  = aws_iam_group.developers.arn
    }
    platform_eng = {
      name = aws_iam_group.platform_eng.name
      arn  = aws_iam_group.platform_eng.arn
    }
  }
}

###############################################################################
# USERS
###############################################################################

output "iam_users" {
  description = "Users criados e os groups aos quais pertencem"
  value = {
    juliana_dev = {
      name   = aws_iam_user.juliana_dev.name
      arn    = aws_iam_user.juliana_dev.arn
      groups = aws_iam_user_group_membership.juliana_dev.groups
    }
    rafael_platform = {
      name   = aws_iam_user.rafael_platform.name
      arn    = aws_iam_user.rafael_platform.arn
      groups = aws_iam_user_group_membership.rafael_platform.groups
    }
    lucas_intern = {
      name   = aws_iam_user.lucas_intern.name
      arn    = aws_iam_user.lucas_intern.arn
      groups = aws_iam_user_group_membership.lucas_intern.groups
    }
  }
}

###############################################################################
# POLICIES
###############################################################################

output "policy_arns" {
  description = "ARNs de todas as custom policies criadas"
  value = {
    s3_read          = aws_iam_policy.s3_read.arn
    ec2_s3_full      = aws_iam_policy.ec2_s3_full.arn
    deny_destructive = aws_iam_policy.deny_destructive.arn
    intern_readonly  = aws_iam_policy.intern_readonly.arn
    ec2_app_data     = aws_iam_policy.ec2_app_data.arn
  }
}

###############################################################################
# SERVICE ROLE
###############################################################################

output "ec2_role_arn" {
  description = "ARN da role assumida pelas instancias EC2"
  value       = aws_iam_role.ec2_role.arn
}

output "ec2_instance_profile" {
  description = "Nome e ARN do instance profile a ser anexado nas instancias EC2"
  value = {
    name = aws_iam_instance_profile.ec2_profile.name
    arn  = aws_iam_instance_profile.ec2_profile.arn
  }
}

###############################################################################
# RESUMO
###############################################################################

output "resumo_entrega" {
  description = "Contagem dos recursos criados nesta entrega"
  value = {
    aluno         = var.aluno
    ra            = var.ra
    groups        = 2
    users         = 3
    policies      = 5
    roles         = 1
    instance_prof = 1
  }
}
