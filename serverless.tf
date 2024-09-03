# Create a zip file for the Lambda function
data "archive_file" "lambda_zip_file" {
  type        = "zip"
  source_file = "lambda/index.js" # Updated path to the actual source file location
  output_path = "lambda/index.zip" # Updated path to the desired output location
}

# Create IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  assume_role_policy = file("lambda-policy.json")
  name               = "lambda_role"
}

# Attach IAM Policy to the Lambda Role
resource "aws_iam_role_policy_attachment" "lambda_exec_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role      = aws_iam_role.lambda_role.name
}

# Create the Lambda Function
resource "aws_lambda_function" "sl_lambda_function" {
  function_name    = "SlLamdaFunction"
  filename         = "lambda/index.zip"  # Corrected reference to output_path
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 30
  source_code_hash = data.archive_file.lambda_zip_file.output_base64sha256

  environment {
    variables = {
      VIDEO_NAME = "Lambda Terraform project"
    }
  }
  }


# Create API Gateway
resource "aws_api_gateway_rest_api" "MyprojectAPI" {
  name        = "myprojectAPI"
  description = "This is the API for my project purposes"
}

resource "aws_api_gateway_resource" "MyprojectAPIResource" {
  rest_api_id = aws_api_gateway_rest_api.MyprojectAPI.id
  parent_id   = aws_api_gateway_rest_api.MyprojectAPI.root_resource_id
  path_part   = "MyprojectAPIresource"
}

resource "aws_api_gateway_method" "MyprojectAPImethod" {
  rest_api_id   = aws_api_gateway_rest_api.MyprojectAPI.id
  resource_id   = aws_api_gateway_resource.MyprojectAPIResource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.MyprojectAPI.id
  resource_id             = aws_api_gateway_resource.MyprojectAPIResource.id
  http_method             = aws_api_gateway_method.MyprojectAPImethod.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.sl_lambda_function.invoke_arn
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.MyprojectAPI.id
  stage_name  = "dev" # Correctly assigned stage name

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.MyprojectAPIResource.id,
      aws_api_gateway_method.MyprojectAPImethod.id, # Correct reference
      aws_api_gateway_integration.lambda_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_integration.lambda_integration] # Fixed typo 'depend_on' to 'depends_on'
}

resource "aws_lambda_permission" "apigw_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sl_lambda_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.MyprojectAPI.execution_arn}/*/*/*"
}

# Output the invoke URL for the API Gateway
output "invoke_url" {
  value = "${aws_api_gateway_rest_api.MyprojectAPI.execution_arn}/dev" # Corrected reference to include the stage name
}
