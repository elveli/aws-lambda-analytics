# AWS Lambda Advanced Showcase

An advanced Serverless event-processing architecture demonstrating production-grade configuration for AWS Lambda using Python, DynamoDB, and SQS. 

This repository leverages Infrastructure-as-code (Terraform) to deploy a highly modular, observable, and scalable backend.

## 🚀 Key Features Demonstrated
- **Asynchronous Event Processing**: SQS triggers for decoupled execution.
- **Custom Runtime**: `provided.al2023` showcasing how to bring a custom Python bootstrap.
- **Lambda Layers**: Externalized dependencies (e.g., `requests`, `boto3`, `aws-xray-sdk`).
- **Advanced Concurrency**: `reserved_concurrent_executions` to prevent noisy-neighbor impact and downstream API limits.
- **Comprehensive Tracing**: AWS X-Ray enabled `Active` tracing for deep-dive performance analysis.
- **DynamoDB Integration**: Robust data persistence.
- **CloudWatch Alarms**: Real-time alerts for high latency and error thresholds.
- **VPC Configuration**: Secure deployment in a `10.56.0.0/16` CIDR block.

## 🧠 Lambda Function Logic (`lambda_function.py`)

The core execution logic is contained in `lambda/src/lambda_function.py`. It is designed for high-performance batch processing and deep observability:

1. **Warm-Start Optimization**: Boto3 client initialization (`dynamodb.Table(...)`) occurs *outside* the `lambda_handler`. This allows subsequent invocations (warm starts) to reuse the connection, significantly reducing latency.
2. **X-Ray Auto-Instrumentation**: The `patch_all()` function intercepts all outbound AWS SDK requests and tracks them automatically. Additionally, the `@xray_recorder.capture('process_single_message')` decorator creates granular subsegments in the trace waterfall for processing individual messages.
3. **Batch Loop Processing**: Because SQS feeds messages in batches (up to 10 at a time, as defined in `terraform/lambda.tf`), the `lambda_handler` iterates over `event.get('Records', [])`. 
4. **Data Enrichment & Persistence**: For each message, it extracts the JSON payload, generates a unique `EventId` (UUID) and `Timestamp`, and persists the enriched item into DynamoDB.
5. **Fault Tolerance**: If an exception occurs, the error is logged and re-raised. This intentional failure prevents the SQS batch from being deleted, triggering an automated retry. After repeated failures, SQS shuttles the message to the configured Dead Letter Queue (DLQ).

## 🛠 Deployment Instructions
Ensure you have the AWS CLI and Terraform installed.

1. Navigate to the `terraform/` directory.
2. Initialize Terraform:
   ```bash
   terraform init
   ```
3. Plan the deployment:
   ```bash
   terraform plan
   ```
4. Apply the infrastructure:
   ```bash
   terraform apply
   ```

## 💻 Execution & Monitoring via CLI

Once deployed, you can trigger the workflow and monitor its execution directly from your terminal using the AWS CLI.

### 1. Trigger the Workflow (via SQS)
Since the Lambda is triggered by SQS, the standard way to execute the flow is to send an SQS message:
```bash
# Get the Queue URL
QUEUE_URL=$(aws sqs get-queue-url --queue-name lambda-showcase-event-queue --query 'QueueUrl' --output text)

# Send a JSON payload message
aws sqs send-message \
    --queue-url $QUEUE_URL \
    --message-body '{"action": "test_process", "event_data": {"device_id": "123", "status": "active"}}'
```

### 2. Direct Lambda Invocation (Testing)
If you need to invoke the Lambda function directly, bypassing the queue:
```bash
aws lambda invoke \
    --function-name LambdaShowcaseProcessor \
    --cli-binary-format raw-in-base64-out \
    --payload '{"Records": [{"body": "{\"manual\": \"invoke\"}"}]}' \
    response.json

# Read the response
cat response.json
```

### 3. Check CloudWatch Logs
To tail the execution logs in real-time, use the CloudWatch Logs tail feature:
```bash
aws logs tail /aws/lambda/LambdaShowcaseProcessor --follow
```

### 4. Verify DynamoDB Persistence
Check if your events successfully landed in the database:
```bash
# Get total item count
aws dynamodb scan \
    --table-name LambdaShowcaseEvents \
    --select COUNT

# View the inserted items
aws dynamodb scan --table-name LambdaShowcaseEvents
```

### 5. Check CloudWatch Alarms
Check the status of the configured alerts (e.g., latency and error thresholds):
```bash
aws cloudwatch describe-alarms \
    --alarm-name-prefix "lambda-showcase" \
    --query 'MetricAlarms[*].[AlarmName, StateValue]' \
    --output table
```

## 💰 Cost Optimization Aspect
This serverless architecture is highly cost-effective, optimized for pay-as-you-go pricing:
- **Compute (Lambda)**: Charged per millisecond of execution and memory allocated. Concurrency limits prevent unexpected runaway costs due to recursive loops.
- **Queue (SQS)**: Standard SQS offers a generous free tier (1 million requests/month) and handles high throughput affordably.
- **Storage (DynamoDB)**: Deployed with **On-Demand Capacity**, ensuring you only pay for actual reads/writes rather than overprovisioned idle capacity.
- **Networking (VPC)**: The architecture avoids NAT Gateway costs by utilizing VPC Endpoints for SQS and DynamoDB, keeping traffic within the AWS backbone.
- **Observability (X-Ray/CloudWatch)**: X-Ray samples a percentage of requests (configurable) to balance visibility with ingestion costs.

## 🌍 Multi-Region Disaster Recovery (DR) Configuration
To achieve enterprise-grade resilience across multiple regions (e.g., `us-east-1` and `us-west-2`):

1. **DynamoDB Global Tables**: 
   - Convert the regional DynamoDB table to a Global Table. This enables active-active multi-region replication.
2. **Multi-Region Queues**: 
   - Deploy SQS queues in both regions. Use Route53 or your event producer to route messages to the secondary region if the primary region's SQS endpoint degrades.
3. **Lambda Redundancy**: 
   - Deploy the Lambda stack in both regions. Since Lambda is stateless, execution seamlessly happens wherever events land.
4. **VPC Peering/Transit Gateway**: 
   - Ensure VPCs (e.g., `10.56.0.0/16` in Primary, `10.57.0.0/16` in Secondary) do not overlap if cross-region routing is required.
5. **Failover Strategy**: 
   - Active/Passive: Primary region processes everything. In disaster, DNS or producers switch to Secondary region. Data is already present via Global Tables.
   - Active/Active: Both regions process traffic. Global tables resolve conflicts using last-writer-wins.
