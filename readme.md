# Car Number Recognition

A serverless application for recognizing car numbers (license plates) using AWS Lambda and Amazon Textract.

## Table of Contents
- Overview
- Architecture
- Setup & Deployment
- Usage
- Technologies Used
- License

## Overview

The Car Number Recognition application allows users to upload an image of a car’s license plate and retrieves the recognized text using Optical Character Recognition (OCR). It leverages AWS Lambda functions and Amazon Textract to provide a scalable and efficient solution.

## Architecture
```mermaid
graph TD
    A[Client] -->|POST /process| B[API Gateway]
    B --> C[ProxyLambda]
    C --> D[RecognitionLambda]
    D --> E[Amazon Textract]
    E --> D
    D --> C
    C --> B
    B --> A
    D --> F[CloudWatch Logs]
    C --> F
```

- Client: Sends a POST request with a Base64-encoded image.
- API Gateway: Serves as the HTTP endpoint to receive requests.
- Lambda1: Validates the input and invokes Lambda2.
- Lambda2: Processes the image using Amazon Textract to extract text.
- Amazon Textract: Performs OCR to detect and analyze text in the image.
- CloudWatch Logs: Logs for monitoring and debugging.

## Usage

Send a POST request to the API endpoint with a JSON payload containing the Base64-encoded image.

### Example curl Command
```bash
curl -X POST https://your-api-id.execute-api.region.amazonaws.com/prod/process \
     -H "Content-Type: application/json" \
     -d '{
           "image": "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"
                         }'
```

### Response
```json
{
  "text": "Extracted text from Amazon Textract...",
  "confidence": 95.4
}
```
