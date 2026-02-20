locals {
  enable_lifecycle = var.lifecycle_policy_max_image_count > 0 || var.lifecycle_policy_untagged_days > 0

  # Raw JSON rules — written as strings with interpolation to guarantee
  # countNumber stays an integer (jsonencode can coerce numbers to strings).
  _untagged_rule = (
    var.lifecycle_policy_untagged_days > 0
    ? "{\"rulePriority\":1,\"description\":\"Expire untagged images after ${var.lifecycle_policy_untagged_days} days\",\"selection\":{\"tagStatus\":\"untagged\",\"countType\":\"sinceImagePushed\",\"countUnit\":\"days\",\"countNumber\":${var.lifecycle_policy_untagged_days}},\"action\":{\"type\":\"expire\"}}"
    : ""
  )

  _max_count_priority = var.lifecycle_policy_untagged_days > 0 ? 2 : 1

  _max_count_rule = (
    var.lifecycle_policy_max_image_count > 0
    ? "{\"rulePriority\":${local._max_count_priority},\"description\":\"Keep only last ${var.lifecycle_policy_max_image_count} images\",\"selection\":{\"tagStatus\":\"any\",\"countType\":\"imageCountMoreThan\",\"countNumber\":${var.lifecycle_policy_max_image_count}},\"action\":{\"type\":\"expire\"}}"
    : ""
  )

  _rules = compact([local._untagged_rule, local._max_count_rule])

  lifecycle_policy_json = "{\"rules\":[${join(",", local._rules)}]}"
}
