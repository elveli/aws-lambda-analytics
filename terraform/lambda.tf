# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda-showcase-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach basic execution role (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach VPC execution role (To allow running in VPC)
resource "aws_iam_role_policy_attachment" "vpc_exec" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Attach X-Ray Daemon Write Access inside VPC and general tracing
resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Custom policy for SQS and DynamoDB
resource "aws_iam_role_policy" "sqs_dynamodb" {
  name   = "sqs-dynamodb-access"
  role   = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.event_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.events_table.arn
      }
    ]
  })
}

# Dummy ZIP file for Lambda payload (Terraform will deploy this, user replaces later in CI/CD)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/src"
  output_path = "${path.module}/../build/lambda.zip"
}

data "archive_file" "layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/layer"
  output_path = "${path.module}/../build/layer.zip"
}

# Lambda Layer
resource "aws_lambda_layer_version" "dependencies" {
  filename            = data.archive_file.layer_zip.output_path
  layer_name          = "lambda-showcase-dependencies"
  compatible_runtimes = ["provided.al2023"] # Matching the custom runtime
  source_code_hash    = data.archive_file.layer_zip.output_base64sha256
}

# Lambda Function
resource "aws_lambda_function" "event_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "LambdaShowcaseProcessor"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Demonstration of Custom Runtime
  runtime = "provided.al2023"

  # Advanced Concurrency Configuration
  # Reserves 10 concurrent executions to prevent this Lambda from scaling excessively
  # and exhausting downstream resources or the region's unreserved concurrency pool.
  reserved_concurrent_executions = 10

  timeout     = 30
  memory_size = 512

  layers = [aws_lambda_layer_version.dependencies.arn]

  # VPC Configuration
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  # Comprehensive Tracing
  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.events_table.name
      LOG_LEVEL      = "INFO"
    }
  }

  tags = {
    lambda-tags = "true"
  }
}

resource "aws_security_group" "lambda_sg" {
  name        = "lambda-showcase-sg"
  description = "Security group for the Lambda function"
  vpc_id      = aws_vpc.main.id

  # Egress to VPC endpoints (HTTPS)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
}

# SQS Trigger (Event Source Mapping)
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.event_queue.arn
  function_name    = aws_lambda_function.event_processor.arn
  batch_size       = 10 # Process up to 10 messages per invocation
  maximum_batching_window_in_seconds = 5 # Wait up to 5s to build a batch
}
