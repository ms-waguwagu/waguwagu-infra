# =============================================================================
# Prometheus
# =============================================================================
resource "helm_release" "prometheus" {
  name       = "prometheus"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"

  create_namespace = false

  values = [
    file("${path.module}/prometheus-values.yaml")
  ]
}

# =============================================================================
# Grafana
# =============================================================================
resource "helm_release" "grafana" {
  name       = "grafana"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"

  create_namespace = false

  values = [
    file("${path.module}/grafana-values.yaml")
  ]

  depends_on = [helm_release.prometheus]
}

# =============================================================================
# Loki (6.x + IRSA + S3)
# =============================================================================
resource "helm_release" "loki" {
  name       = "loki"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "6.46.0"

  values = [
    file("${path.module}/configs/loki-values.yaml"),
    yamlencode({
      deploymentMode = "SingleBinary"

      singleBinary = {
        replicas = 1
      }

      read = {
        enabled  = false
        replicas = 0
      }

      write = {
        enabled  = false
        replicas = 0
      }

      backend = {
        enabled  = false
        replicas = 0
      }

      persistence = {
        enabled = false
      }

      loki = {
        storage = {
          bucketNames = {
            chunks = data.aws_cloudformation_export.loki_bucket_name.value
            ruler  = data.aws_cloudformation_export.loki_bucket_name.value
            admin  = data.aws_cloudformation_export.loki_bucket_name.value
          }
        }
      }

      serviceAccount = {
        create = true
        name   = "loki"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.loki.arn
        }
      }
    })
  ]




  depends_on = [
    aws_iam_role_policy.loki,
    kubernetes_namespace.monitoring
  ]
}

# =============================================================================
# Promtail
# =============================================================================
resource "helm_release" "promtail" {
  name       = "promtail"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = "6.15.5"

  values = [
    file("${path.module}/configs/promtail-values.yaml")
  ]

  depends_on = [
    helm_release.loki,
    kubernetes_namespace.monitoring
  ]
}
