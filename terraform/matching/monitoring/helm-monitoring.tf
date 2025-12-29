# =============================================================================
# Prometheus
# =============================================================================
resource "helm_release" "prometheus" {
  name       = "prometheus"
  namespace  = "monitoring"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"

  create_namespace = true

  values = [
    file("${path.module}/prometheus-values.yaml")
  ]
}

# =============================================================================
# Grafana
# =============================================================================
resource "helm_release" "grafana" {
  name       = "grafana"
  namespace  = "monitoring"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"

  create_namespace = true

  values = [
    file("${path.module}/grafana-values.yaml")
  ]

  depends_on = [helm_release.prometheus]
}

# =============================================================================
# Loki
# =============================================================================

resource "helm_release" "loki" {
  name       = "loki"
  namespace  = "monitoring"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "5.47.2"

  timeout = 150
  wait    = true

  values = [
    templatefile("${path.module}/loki-values.yaml", {
      loki_role_arn = aws_iam_role.loki.arn
      region        = var.region
    })
  ]

  depends_on = [
    aws_iam_role_policy.loki
  ]
}

resource "helm_release" "promtail" {
  name       = "promtail"
  namespace  = "monitoring"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"

  values = [<<EOF
config:
  clients:
    - url: http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push

  scrape_configs:
    - job_name: kubernetes-pods
      kubernetes_sd_configs:
        - role: pod

      relabel_configs:
        # namespace 라벨
        - source_labels: [__meta_kubernetes_namespace]
          target_label: namespace

        # pod 이름 라벨
        - source_labels: [__meta_kubernetes_pod_name]
          target_label: pod

        # container 이름 라벨
        - source_labels: [__meta_kubernetes_pod_container_name]
          target_label: container

        # 로그 파일 경로 (필수)
        - source_labels: [__meta_kubernetes_pod_uid, __meta_kubernetes_pod_container_name]
          separator: /
          target_label: __path__
          replacement: /var/log/pods/*$1/*.log
EOF
  ]
}
