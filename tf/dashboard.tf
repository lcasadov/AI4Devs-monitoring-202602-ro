# Dashboard completo: combina métricas del agente (host) y de CloudWatch (EC2).
# No toca el datadog_dashboard.ec2_dashboard de main.tf.
resource "datadog_dashboard" "full_monitoring" {
  title       = "LTI - Full Monitoring"
  description = "Monitorización completa: host (agente) + EC2 (CloudWatch)"
  layout_type = "ordered"

  # ---------- Grupo 1: Resumen (valores actuales) ----------
  widget {
    group_definition {
      title       = "Resumen"
      layout_type = "ordered"

      widget {
        query_value_definition {
          title = "CPU usuario (%)"
          request {
            q          = "avg:system.cpu.user{*}"
            aggregator = "avg"
          }
        }
      }

      widget {
        query_value_definition {
          title = "Memoria usada (bytes)"
          request {
            q          = "avg:system.mem.used{*}"
            aggregator = "avg"
          }
        }
      }

      widget {
        query_value_definition {
          title = "Carga del sistema (1m)"
          request {
            q          = "avg:system.load.1{*}"
            aggregator = "avg"
          }
        }
      }
    }
  }

  # ---------- Grupo 2: Host (métricas del agente) ----------
  widget {
    group_definition {
      title       = "Host (agente)"
      layout_type = "ordered"

      widget {
        timeseries_definition {
          title = "CPU por estado"
          request {
            q            = "avg:system.cpu.user{*} by {host}"
            display_type = "line"
          }
          request {
            q            = "avg:system.cpu.system{*} by {host}"
            display_type = "line"
          }
          request {
            q            = "avg:system.cpu.idle{*} by {host}"
            display_type = "line"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Memoria usada vs total"
          request {
            q            = "avg:system.mem.used{*} by {host}"
            display_type = "area"
          }
          request {
            q            = "avg:system.mem.total{*} by {host}"
            display_type = "line"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Disco en uso (%)"
          request {
            q            = "avg:system.disk.in_use{*} by {host,device}"
            display_type = "line"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Red del host (bytes)"
          request {
            q            = "avg:system.net.bytes_rcvd{*} by {host}"
            display_type = "line"
          }
          request {
            q            = "avg:system.net.bytes_sent{*} by {host}"
            display_type = "line"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Carga del sistema (1/5/15m)"
          request {
            q            = "avg:system.load.1{*} by {host}"
            display_type = "line"
          }
          request {
            q            = "avg:system.load.5{*} by {host}"
            display_type = "line"
          }
          request {
            q            = "avg:system.load.15{*} by {host}"
            display_type = "line"
          }
        }
      }
    }
  }

  # ---------- Grupo 3: EC2 (CloudWatch vía integración) ----------
  widget {
    group_definition {
      title       = "EC2 (CloudWatch)"
      layout_type = "ordered"

      widget {
        timeseries_definition {
          title = "CPU EC2 (%)"
          request {
            q            = "avg:aws.ec2.cpuutilization{*} by {instance_id}"
            display_type = "line"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Network In"
          request {
            q            = "avg:aws.ec2.network_in{*} by {instance_id}"
            display_type = "area"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Network Out"
          request {
            q            = "avg:aws.ec2.network_out{*} by {instance_id}"
            display_type = "area"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Status check fallidos"
          request {
            q            = "avg:aws.ec2.status_check_failed{*} by {instance_id}"
            display_type = "bars"
          }
        }
      }
    }
  }
}

output "full_monitoring_dashboard_url" {
  value = "https://app.datadoghq.eu/dashboard/${datadog_dashboard.full_monitoring.id}"
}
