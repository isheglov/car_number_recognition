import os
import json
import boto3
import base64

lambda_client = boto3.client('lambda')

def lambda_handler(event, context):
    # Extract the function name for Lambda2 from environment variables
    function_name = os.environ.get('LAMBDA2_FUNCTION_NAME')
    
    if not function_name:
        return {
            'statusCode': 500,
            'body': json.dumps({'message': 'LAMBDA2_FUNCTION_NAME not set'})
        }
    
    try:
        # Parse the incoming JSON payload
        if 'body' in event:
            # If the Lambda is invoked via API Gateway, the payload is in event['body']
            body = json.loads(event['body'])
        else:
            # Direct invocation
            body = event
        
        image_b64 = body.get('image', '').strip()
        
        # Validation 1: Input is not empty
        if not image_b64:
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'The "image" field is required and cannot be empty.'})
            }
        
        # Validation 2: Image is below 1024 KB
        if len(image_b64) > 1_048_576:  # 1 MB = 1,048,576 bytes
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'The image size must be 1024 KB or less.'})
            }

        # Validation 3: String has a base64 format
        try:
            image_bytes = base64.b64decode(image_b64, validate=True)
        except (base64.binascii.Error, ValueError):
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'The "image" field must be a valid base64-encoded string.'})
            }
        
                
        # Validation 4: Image is below 1024 KB
        if len(image_bytes) > 1_048_576:  # 1 MB = 1,048,576 bytes
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'The image size must be 1024 KB or less.'})
            }
        
        # If all validations pass, invoke Lambda2
        response = lambda_client.invoke(
            FunctionName=function_name,
            InvocationType='RequestResponse',  # Use 'Event' for asynchronous invocation
            Payload=json.dumps(body)
        )
        
        payload = response['Payload'].read()
        response_payload = json.loads(payload)
        
        return {
            'statusCode': 200,
            'body': json.dumps(response_payload),
        }
        
    except Exception as e:
        # Log the exception details (optional)
        print(f"Error: {str(e)}")
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Internal server error while invoking Lambda2.',
                'error': str(e)
            }),
        }
    