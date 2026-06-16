resource "aws_dynamodb_table" "events_table" {
  name         = "LambdaShowcaseEvents"
  billing_mode = "PAY_PER_REQUEST" # Serverless cost optimization
  hash_key     = "EventId"
  range_key    = "Timestamp"

  attribute {
    name = "EventId"
    type = "S"
  }

  attribute {
    name = "Timestamp"
    type = "N"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    lambda-tags = "true"
  }
}
