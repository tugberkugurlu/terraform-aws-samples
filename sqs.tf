provider "aws" {}

# https://www.terraform.io/docs/providers/aws/r/sqs_queue.html
resource "aws_sqs_queue" "main-queue" {
    name = "tugberk-sample-queue"
    fifo_queue = false
    receive_wait_time_seconds = 20

    tags = {
        Environment = "sandbox"
        Owner = "tugberk.ugurlu"
        Purpose = "dev_and_test"
    }
}

# AssumeRole https://stackoverflow.com/a/44658378/463785
resource "aws_iam_role" "iam_for_lambda" {
  name = "tugberk_iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "sqs-receive-policy-document" {
  statement {
    sid = "1"

    actions = [
      "sqs:*",
    ]

    resources = [
      "${aws_sqs_queue.main-queue.arn}",
    ]
  }
}

resource "aws_iam_policy" "sqs-receive-policy" {
  name   = "tugberk_sqs-receive-policy"
  policy = "${data.aws_iam_policy_document.sqs-receive-policy-document.json}"
}

resource "aws_lambda_function" "main-func" {
    function_name = "tugberk-sample-dequeuer"
    filename = "app.zip"
    source_code_hash = "${base64sha256(file("app.zip"))}"
    handler = "exports.myHandler"
    runtime = "nodejs8.10"
    role = "${aws_iam_role.iam_for_lambda.arn}"
}

resource "aws_lambda_event_source_mapping" "example" {
  event_source_arn = "${aws_sqs_queue.main-queue.arn}"
  function_name    = "${aws_lambda_function.main-func.arn}"
}

# This is to optionally manage the CloudWatch Log Group for the Lambda Function.
# If skipping this resource configuration, also add "logs:CreateLogGroup" to the IAM policy below.
resource "aws_cloudwatch_log_group" "main_lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.main-func.function_name}"
  retention_in_days = 1
}

# See also the following AWS managed policy: AWSLambdaBasicExecutionRole
resource "aws_iam_policy" "main_lambda_logging" {
  name = "tugberk_lambda_logging"
  path = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "main_lambda_logs" {
  role = "${aws_iam_role.iam_for_lambda.name}"
  policy_arn = "${aws_iam_policy.main_lambda_logging.arn}"
}

resource "aws_iam_role_policy_attachment" "sqs-receive-policy-attachment" {
    role = "${aws_iam_role.iam_for_lambda.name}"
    policy_arn = "${aws_iam_policy.sqs-receive-policy.arn}"
}


## 1: create a lambda to pull messages from sqs
## 2: for that, we need to have an iam for the lambda which would have the policy attached to receive, delete messages from the queue
## 3: we need to wire up the queue with the lambda so that queue can wake up the lambda