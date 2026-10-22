locals {
  tags    = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  base    = "${var.name}-${var.environment}"
  runtime = { python = "python3.13", node = "nodejs22.x" }
  handler = { python = "main.handler", node = "index.handler" }
  code = {
    python = { file = "main.py", body = "def handler(event, context):\n    for record in event.get(\"Records\", []):\n        print(record[\"body\"])\n    return {\"ok\": True}\n" }
    node   = { file = "index.mjs", body = "export const handler = async (event) => {\n  for (const r of event.Records ?? []) console.log(r.body);\n  return { ok: true };\n};\n" }
  }
}

# Código inicial de ejemplo: el equipo lo reemplaza desde su pipeline.
data "archive_file" "code" {
  type        = "zip"
  output_path = "${path.module}/.build/${local.base}.zip"
  source {
    filename = local.code[var.language].file
    content  = local.code[var.language].body
  }
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${local.base}-dlq"
  sqs_managed_sse_enabled   = true
  message_retention_seconds = 1209600
}

# Cola cifrada con cola de mensajes fallidos.
resource "aws_sqs_queue" "this" {
  name                       = local.base
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = var.timeout_s * 6
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.base}"
  retention_in_days = 30
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Rol mínimo: escribir sus registros, trazas y leer solo su cola.
data "aws_iam_policy_document" "this" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
  statement {
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
    resources = [aws_sqs_queue.this.arn]
  }
  statement {
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "this" {
  name               = "lambda-${local.base}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy" "this" {
  name   = "funcion"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_lambda_function" "this" {
  function_name    = local.base
  role             = aws_iam_role.this.arn
  runtime          = local.runtime[var.language]
  handler          = local.handler[var.language]
  architectures    = ["arm64"]
  filename         = data.archive_file.code.output_path
  source_code_hash = data.archive_file.code.output_base64sha256
  memory_size      = var.memory_mb
  timeout          = var.timeout_s

  tracing_config {
    mode = "Active"
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.this.name
  }

  environment {
    variables = { QUEUE_URL = aws_sqs_queue.this.url }
  }

  depends_on = [aws_iam_role_policy.this]
}

resource "aws_lambda_event_source_mapping" "this" {
  event_source_arn        = aws_sqs_queue.this.arn
  function_name           = aws_lambda_function.this.arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = max(2, var.max_instances)
  }
}
