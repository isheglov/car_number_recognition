import json
import base64
import boto3
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
textract = boto3.client('textract')
rekognition = boto3.client('rekognition')

def lambda_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))
    
    try:
        # Parse the incoming payload
        if 'body' in event:
            # If invoked via API Gateway
            body = json.loads(event['body'])
            logger.info("Parsed body from API Gateway.")
        else:
            # Direct invocation
            body = event
            logger.info("Parsed body from direct invocation.")

        image_b64 = body.get('image', '').strip()
        logger.info("Extracted 'image' field.")

        if not image_b64:
            logger.warning("The 'image' field is missing or empty.")
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'The "image" field is required and cannot be empty.'})
            }

        # Decode the Base64 image
        try:
            image_bytes = base64.b64decode(image_b64, validate=True)
            logger.info("Successfully decoded Base64 image.")
        except (base64.binascii.Error, ValueError) as decode_error:
            logger.error("Base64 decoding failed: %s", str(decode_error))
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'The "image" field must be a valid base64-encoded string.'})
            }

        # Perform OCR using Amazon Textract
        textract_text = ""
        textract_confidences = []
        try:
            textract_response = textract.detect_document_text(
                Document={'Bytes': image_bytes}
            )
            logger.info("Textract response received.")
            
            for item in textract_response.get('Blocks', []):
                if item['BlockType'] == 'LINE':
                    textract_text += item['Text'] + '\n'
                    textract_confidences.append(item.get('Confidence', 0))
            textract_text = textract_text.strip()
            logger.info("Extracted text from Textract.")

            # Calculate average confidence
            if textract_confidences:
                textract_avg_confidence = sum(textract_confidences) / len(textract_confidences)
                logger.info("Calculated average confidence for Textract: %s", textract_avg_confidence)
            else:
                textract_avg_confidence = 0
                logger.warning("No confidence scores found in Textract response.")

        except Exception as textract_error:
            logger.error("Textract processing failed: %s", str(textract_error))
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'message': 'OCR processing failed with Textract.',
                    'error': str(textract_error)
                }),
            }

        # Perform OCR using Amazon Rekognition
        rekognition_text = ""
        rekognition_confidences = []
        try:
            rekognition_response = rekognition.detect_text(
                Image={'Bytes': image_bytes}
            )
            logger.info("Rekognition response received.")
            
            for text_detect in rekognition_response.get('TextDetections', []):
                if text_detect['Type'] == 'LINE':
                    rekognition_text += text_detect['DetectedText'] + '\n'
                    rekognition_confidences.append(text_detect.get('Confidence', 0))
            rekognition_text = rekognition_text.strip()
            logger.info("Extracted text from Rekognition.")

            # Calculate average confidence
            if rekognition_confidences:
                rekognition_avg_confidence = sum(rekognition_confidences) / len(rekognition_confidences)
                logger.info("Calculated average confidence for Rekognition: %s", rekognition_avg_confidence)
            else:
                rekognition_avg_confidence = 0
                logger.warning("No confidence scores found in Rekognition response.")

        except Exception as rekognition_error:
            logger.error("Rekognition processing failed: %s", str(rekognition_error))
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'message': 'OCR processing failed with Rekognition.',
                    'error': str(rekognition_error)
                }),
            }

        # Compare confidences and determine which OCR tool performed better
        result_text = rekognition_text
        if textract_avg_confidence > rekognition_avg_confidence:
            result_text = textract_text
        
        return {'text': result_text}

    except Exception as e:
        logger.exception("An unexpected error occurred: %s", str(e))
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Internal server error during OCR processing.',
                'error': str(e)
            }),
        }
