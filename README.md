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

## ⚙️ Custom Runtime Architecture (`provided.al2023`)

The application is deployed using the `provided.al2023` Lambda runtime. This is an advanced technique rather than using a standard managed runtime (like `python3.12`):

- **Bare Metal OS**: `provided.al2023` provides a minimal Amazon Linux 2023 environment without any pre-installed language runtimes.
- **The `bootstrap` File**: When Lambda provisions this environment, it requires an executable file named `bootstrap`. Our repository includes `lambda/src/bootstrap` which serves as the main entry point for the container.
- **Runtime Interface Client (RIC)**: The `bootstrap` script initializes the environment and executes the `awslambdaric` package (AWS Lambda Runtime Interface Client). The RIC handles HTTP polling for new events from the AWS Lambda Runtime API and routes them to our `lambda_function.py`.
- **Advanced Use Cases**: This pattern gives you complete control over the execution environment. You can compile alternative Python versions from source, inject monitoring agents that need to run as parallel processes, or execute statically compiled binaries.

> **Note on `python3: not found` execution errors:** `provided.al2023` is a completely bare OS image. If you attempt to invoke this Lambda as-is, you will receive `Runtime.ExitError: exit status 127` because `python3` does not exist on the image. In a real-world scenario, you must statically compile Python and bundle it into the layer, or compile and upload your application using a Docker image (`Image` package type). For ease of execution out-of-the-box, the `terraform/lambda.tf` has been updated to use the fully managed `python3.12` runtime while preserving the `provided.al2023` scripting for demonstration purposes.

## 🛠 Deployment Instructions
Ensure you have the AWS CLI, Terraform, and Python/pip installed.

We have included a convenience script that automatically compiles the Python layer dependencies and applies the Terraform configuration:

```bash
chmod +x deploy.sh
./deploy.sh
```

> **Fixing `Runtime.ImportModuleError: No module named 'aws_xray_sdk'`:** 
> If you deployed manually and encountered this error, it means Terraform packaged an empty Lambda layer because the dependencies were not downloaded first. Running `./deploy.sh` resolves this by cleanly installing `requirements.txt` into a `python/` subfolder (which AWS extracts to `/opt/python/` in the Lambda execution environment) before running `terraform apply`.

> **Fixing `Task timed out after 30.00 seconds`:**
> If you encounter a hard timeout when running the function, it is likely a network routing issue. By default, Lambdas placed in a VPC lose internet access. While `terraform/vpc.tf` defines Endpoints for SQS and DynamoDB, you must ensure that your Lambda's Security Group allows outbound traffic (`0.0.0.0/0`). Without this, requests to the DynamoDB Gateway Endpoint (which resolves to public AWS prefix lists) are silently dropped, causing boto3 to hang until timeout. The repository's security group settings update has been patched to fix this.

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

### 6. Analyze X-Ray Traces via CLI & Console
This application is configured with `Active` tracing using AWS X-Ray, which intercepts requests made via boto3 (e.g., to DynamoDB and SQS) and maps out execution latency.

**Via AWS Console:**
1. Navigate to **CloudWatch** > **X-Ray traces** > **Service map** in the AWS Management Console.
2. You will see a visual node graph demonstrating the path from your Lambda function to DynamoDB.
3. Click on **Traces**, apply the `service("LambdaShowcaseProcessor")` filter, and click on any trace ID. This will open a detailed waterfall diagram showing exactly how many milliseconds the `PutItem` DynamoDB operation or the `process_single_message` subsegment took.

**Via AWS CLI:**
```bash
# 1. Define time window (last 10 minutes)
START_TIME=$(date -u -d '10 minutes ago' +%s 2>/dev/null || date -u -v-10m +%s)
END_TIME=$(date -u +%s)

# 2. Get trace summaries
aws xray get-trace-summaries \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'TraceSummaries[*].Id' \
    --output text

# 3. Retrieve detailed waterfall timeline for a specific trace ID
# (replace the ID below with one outputted by the previous command)
aws xray batch-get-traces --trace-ids "1-6a31b2d9-02bce06439f77cbc3e618984"
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
