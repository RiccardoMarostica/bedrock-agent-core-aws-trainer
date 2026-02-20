#####
# ----- IAM ROLE -----
# This section is for the IAM Role configuration.
# This creates an IAM Role with configuration options - managed policies and custom policies.
#####
resource "aws_iam_role" "role" {
  name               = var.name
  assume_role_policy = var.assume_role_policy
}

# Add managed policies to IAM Role.
resource "aws_iam_role_policy_attachment" "managed_policies" {
  count      = local.enable_custom_policies ? length(var.managed_policies) : 0
  role       = aws_iam_role.role.name
  policy_arn = var.managed_policies[count.index]
}

# Define custom policies.
# Multiple association to the role is possible.
resource "aws_iam_policy" "custom_policies" {
  count       = local.enable_custom_policies ? length(var.custom_policies) : 0
  name        = var.custom_policies[count.index].name
  description = var.custom_policies[count.index].description
  policy      = var.custom_policies[count.index].policy
}

# Add custom policies to IAM role.
# Multiple association to the role is possible.
resource "aws_iam_role_policy_attachment" "custom_policies" {
  count      = local.enable_custom_policies ? length(var.custom_policies) : 0
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.custom_policies[count.index].arn
}

