resource "aws_sqs_queue" "event_queue" {
  name                       = "lambda-showcase-event-queue"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 10 # Long polling
  visibility_timeout_seconds = 60 # Should be >= Lambda timeout

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    lambda-tags = "true"
  }
}

resource "aws_sqs_queue" "dlq" {
  name = "lambda-showcase-event-dlq"

  tags = {
    lambda-tags = "true"
  }
}
