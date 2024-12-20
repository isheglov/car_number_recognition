provider "aws" {
  region = var.region
}

######################
# IAM Roles and Policies
######################

# Role for Lambda Functions
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_execution_role"

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

# Basic execution policy for Lambda functions (CloudWatch Logs)
resource "aws_iam_policy" "lambda_basic_execution" {
  name        = "lambda_basic_execution"
  description = "Basic execution policy for Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Effect   = "Allow"
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_basic_execution.arn
}

# Policy for Lambda2 to use Amazon Textract
resource "aws_iam_policy" "lambda_textract_policy" {
  name        = "lambda_textract_policy"
  description = "Allows Lambda2 to use Amazon Textract"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "textract:DetectDocumentText",
          "textract:AnalyzeDocument"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_textract_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_textract_policy.arn
}

resource "aws_iam_policy" "lambda_rekognition_policy" {
  name        = "lambda_rekognition_policy"
  description = "Allows Lambda2 to use Amazon Rekognition"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rekognition:DetectText"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach Rekognition Policy to the Lambda Execution Role
resource "aws_iam_role_policy_attachment" "lambda_rekognition_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_rekognition_policy.arn
}


######################
# Lambda Function 2
######################

resource "aws_lambda_function" "lambda2" {
  function_name = var.lambda2_function_name
  handler       = "lambda2.lambda_handler"
  runtime       = "python3.9"

  role = aws_iam_role.lambda_exec_role.arn

  filename         = "lambda2.zip" # Path to your Lambda2 deployment package
  source_code_hash = filebase64sha256("lambda2.zip")

  memory_size = 512  # Adjust based on OCR processing needs
  timeout     = 30   # Adjust based on OCR processing needs

  environment {
    variables = {
      # Add environment variables if needed
    }
  }

  # Removed layers since they are no longer needed
}

######################
# Lambda Function 1
######################

resource "aws_lambda_function" "lambda1" {
  function_name = var.lambda1_function_name
  handler       = "lambda1.lambda_handler"
  runtime       = "python3.9"

  role = aws_iam_role.lambda_exec_role.arn

  filename         = "lambda1.zip" # Path to your Lambda1 deployment package
  source_code_hash = filebase64sha256("lambda1.zip")

  environment {
    variables = {
      LAMBDA2_FUNCTION_NAME = aws_lambda_function.lambda2.function_name
    }
  }
}

######################
# API Gateway
######################

resource "aws_api_gateway_rest_api" "api" {
  name        = var.api_gateway_name
  description = "API Gateway to trigger Lambda1"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.lambda1.invoke_arn
}

# Permission for API Gateway to invoke Lambda1
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda1.function_name
  principal     = "apigateway.amazonaws.com"

  # The source ARN should match the API Gateway's ARN
  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Deploy the API
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"
}

######################
# Outputs
######################

output "api_endpoint" {
  value = aws_api_gateway_deployment.api_deployment.invoke_url
}

output "lambda1_function_name" {
  value = aws_lambda_function.lambda1.function_name
}

output "lambda2_function_name" {
  value = aws_lambda_function.lambda2.function_name
}