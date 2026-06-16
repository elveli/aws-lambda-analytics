resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "lambda-showcase-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "60" # 1 minute
  statistic           = "Average"
  threshold           = "3000" # 3 seconds
  alarm_description   = "This alarm triggers when Lambda function latency exceeds 3 seconds."
  
  dimensions = {
    FunctionName = aws_lambda_function.event_processor.function_name
  }

  tags = {
    lambda-tags = "true"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "lambda-showcase-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "5"
  
  dimensions = {
    FunctionName = aws_lambda_function.event_processor.function_name
  }

  tags = {
    lambda-tags = "true"
  }
}
