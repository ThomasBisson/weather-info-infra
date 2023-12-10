terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws",
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

resource "aws_iam_role_policy" "logs_policy" {
  name = "logs-policy"
  role = aws_iam_role.weather_info_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:eu-west-1:600211763550:log-group:/aws/lambda/weather-info-api:*"
      },
      {
        Action = [
          "logs:CreateLogGroup"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:eu-west-1:600211763550:*"
      },
    ]
  })
}

resource "aws_iam_role" "weather_info_lambda_role" {
  name = "weather-info-lambda-role-${terraform.workspace}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_lambda_function" "weather_info_lambda" {
  function_name = "weather-info-api-${terraform.workspace}"
  role          = aws_iam_role.weather_info_lambda_role.arn
  handler       = "index.handler"

  filename = "code/index.zip"

  runtime = "nodejs20.x"

  environment {
    variables = {
      NODE_ENV       = "production"
      WEATHERBIT_KEY = "e44b8d942c3544f89e83eed541295f17"
      WEATHERBIT_URL = "https://api.weatherbit.io/v2.0/"
    }
  }
}

resource "aws_cloudwatch_log_group" "weather_info_lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.weather_info_lambda.function_name}"
  retention_in_days = 14
}



resource "aws_api_gateway_rest_api" "weather_info_api_gateway_rest" {
  name = "weathe-info-${terraform.workspace}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "weather_info_api_gateway_rest_resource_weather" {
  rest_api_id = aws_api_gateway_rest_api.weather_info_api_gateway_rest.id
  parent_id   = aws_api_gateway_rest_api.weather_info_api_gateway_rest.root_resource_id
  path_part   = "weather"
}

resource "aws_api_gateway_resource" "weather_info_api_gateway_rest_resource_weather_current" {
  rest_api_id = aws_api_gateway_rest_api.weather_info_api_gateway_rest.id
  parent_id   = aws_api_gateway_resource.weather_info_api_gateway_rest_resource_weather.id
  path_part   = "current"
}

resource "aws_api_gateway_resource" "weather_info_api_gateway_rest_resource_weather_forecast" {
  rest_api_id = aws_api_gateway_rest_api.weather_info_api_gateway_rest.id
  parent_id   = aws_api_gateway_resource.weather_info_api_gateway_rest_resource_weather.id
  path_part   = "forecast"
}

resource "aws_api_gateway_method" "weather_info_api_gateway_weather_current" {
  rest_api_id   = aws_api_gateway_rest_api.weather_info_api_gateway_rest.id
  resource_id   = aws_api_gateway_resource.weather_info_api_gateway_rest_resource_weather_current.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "weather_info_api_gateway_weather_forecast" {
  rest_api_id   = aws_api_gateway_rest_api.weather_info_api_gateway_rest.id
  resource_id   = aws_api_gateway_resource.weather_info_api_gateway_rest_resource_weather_forecast.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "weather_info_api_gateway_weather_current_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.weather_info_api_gateway_rest.id
  resource_id             = aws_api_gateway_resource.weather_info_api_gateway_rest_resource_weather_current.id
  http_method             = aws_api_gateway_method.weather_info_api_gateway_weather_current.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.weather_info_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "weather_info_api_gateway_weather_forecast_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.weather_info_api_gateway_rest.id
  resource_id             = aws_api_gateway_resource.weather_info_api_gateway_rest_resource_weather_forecast.id
  http_method             = aws_api_gateway_method.weather_info_api_gateway_weather_forecast.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.weather_info_lambda.invoke_arn
}

resource "aws_lambda_permission" "weather_info_api_gateway_weather_current_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.weather_info_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:eu-west-1:600211763550:${aws_api_gateway_rest_api.weather_info_api_gateway_rest.id}/*/*"
}

resource "aws_api_gateway_deployment" "weather_info_api_gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.weather_info_api_gateway_rest.id
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.weather_info_api_gateway_rest.body))
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    aws_api_gateway_method.weather_info_api_gateway_weather_current,
    aws_api_gateway_integration.weather_info_api_gateway_weather_current_lambda_integration,
    aws_api_gateway_method.weather_info_api_gateway_weather_forecast,
    aws_api_gateway_integration.weather_info_api_gateway_weather_forecast_lambda_integration,
  ]
}

resource "aws_api_gateway_stage" "aws_api_gateway_stage" {
  rest_api_id   = aws_api_gateway_rest_api.weather_info_api_gateway_rest.id
  stage_name    = terraform.workspace
  deployment_id = aws_api_gateway_deployment.weather_info_api_gateway_deployment.id
}

