# Integración AWS <-> Datadog (método role delegation)
# Datadog asume un rol en esta cuenta de AWS para leer métricas de CloudWatch/EC2/Logs.

data "aws_caller_identity" "current" {}

# 1. Registra la cuenta de AWS en Datadog y genera el external_id de autenticación
resource "datadog_integration_aws" "main" {
  account_id = data.aws_caller_identity.current.account_id
  role_name  = "DatadogAWSIntegrationRole"
  # host_tags = ["project:lti"]   # opcional: etiqueta los recursos descubiertos
}

# 2. Rol que Datadog (cuenta AWS 464622532012) puede asumir, restringido por external_id
resource "aws_iam_role" "datadog_integration" {
  name = "DatadogAWSIntegrationRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = "arn:aws:iam::464622532012:root" }
      Condition = {
        StringEquals = {
          "sts:ExternalId" = datadog_integration_aws.main.external_id
        }
      }
    }]
  })
}

# 3. Adjunta la política de lectura (definida en main.tf como aws_iam_policy.datadog_policy) al rol
resource "aws_iam_role_policy_attachment" "datadog_integration" {
  role       = aws_iam_role.datadog_integration.name
  policy_arn = aws_iam_policy.datadog_policy.arn
}
