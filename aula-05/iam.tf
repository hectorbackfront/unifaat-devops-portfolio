# O AWS Academy Learner Lab não permite criar Roles/Instance Profiles IAM
# pelo Terraform — reutilizamos o Instance Profile "LabInstanceProfile"
# já provisionado pelo ambiente do Academy (mesma abordagem da Aula 04).
data "aws_iam_instance_profile" "lab_role" {
  name = var.iam_instance_profile_name
}
