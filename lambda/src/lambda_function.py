import json
import os
import time
import uuid
import boto3
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch_all

# Patch all supported libraries for X-Ray tracing
patch_all()

# Initialize resources outside the handler for reuse across executions (warm starts)
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('DYNAMODB_TABLE', 'LambdaShowcaseEvents')
table = dynamodb.Table(table_name)

@xray_recorder.capture('process_single_message')
def process_message(record):
    """
    Processes a single SQS message and saves it to DynamoDB.
    """
    body = record.get('body', '{}')
    
    # Simulate processing time
    time.sleep(0.1) 
    
    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        data = {"raw_body": body}
    
    event_id = str(uuid.uuid4())
    timestamp = int(time.time() * 1000)
    
    # Save to DynamoDB
    table.put_item(
        Item={
            'EventId': event_id,
            'Timestamp': timestamp,
            'Data': data,
            'SourceMessageId': record.get('messageId')
        }
    )
    return event_id

def lambda_handler(event, context):
    """
    Main Lambda entry point. SQS triggers pass event data here.
    """
    records = event.get('Records', [])
    print(f"Received {len(records)} records from SQS to process.")
    
    processed_ids = []
    
    # Process SQS batch
    for record in records:
        try:
            event_id = process_message(record)
            processed_ids.append(event_id)
        except Exception as e:
            # We log the error. In production with SQS batching, 
            # consider using SQS partial batch responses.
            print(f"Error processing record {record.get('messageId')}: {e}")
            raise e
            
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Processing complete",
            "processed_count": len(processed_ids),
            "event_ids": processed_ids
        })
    }
