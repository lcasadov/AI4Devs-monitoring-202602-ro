# Set de alertas (datadog_monitor) para el host y la instancia EC2.
# Destino de notificación parametrizable: define TF_VAR_alert_notification
# (p. ej. "@lcasadov@gmail.com" o "@slack-canal"). Vacío = solo visible en Datadog.
variable "alert_notification" {
  description = "Destinatario de las alertas (@email, @slack-...). Vacío = sin notificar."
  type        = string
  default     = ""
}

locals {
  monitor_tags = ["project:lti", "managed-by:terraform"]
}

# 1) CPU alta (host / agente)
resource "datadog_monitor" "cpu_alta" {
  name    = "CPU alta en host"
  type    = "metric alert"
  message = "CPU de usuario al {{value}}% en {{host.name}} (umbral 85%). ${var.alert_notification}"
  query   = "avg(last_5m):avg:system.cpu.user{*} by {host} > 85"

  monitor_thresholds {
    warning  = 70
    critical = 85
  }

  notify_no_data    = true
  no_data_timeframe = 10
  renotify_interval = 60
  include_tags      = true
  tags              = local.monitor_tags
}

# 2) Memoria alta (% usado)
resource "datadog_monitor" "memoria_alta" {
  name    = "Memoria alta en host"
  type    = "metric alert"
  message = "Memoria realmente usada al {{value}}% en {{host.name}} (umbral 90%, descuenta cache). ${var.alert_notification}"
  query   = "avg(last_5m):( 1 - avg:system.mem.usable{*} by {host} / avg:system.mem.total{*} by {host} ) * 100 > 90"

  monitor_thresholds {
    warning  = 80
    critical = 90
  }

  notify_no_data    = true
  no_data_timeframe = 10
  renotify_interval = 60
  include_tags      = true
  tags              = local.monitor_tags
}

# 3) Disco lleno
resource "datadog_monitor" "disco_lleno" {
  name    = "Disco lleno en host"
  type    = "metric alert"
  message = "Disco al {{value}}% en {{host.name}} ({{device.name}}, umbral 90%). ${var.alert_notification}"
  query   = "avg(last_5m):avg:system.disk.in_use{!device:/dev/loop0,!device:/dev/loop1,!device:/dev/loop2,!device:/dev/loop3,!device:/dev/loop4,!device:/dev/loop5,!device:/dev/loop6,!device:/dev/loop7} by {host,device} * 100 > 90"

  monitor_thresholds {
    warning  = 80
    critical = 90
  }

  notify_no_data    = true
  no_data_timeframe = 10
  renotify_interval = 60
  include_tags      = true
  tags              = local.monitor_tags
}

# 4) Carga del sistema alta
resource "datadog_monitor" "carga_alta" {
  name    = "Carga del sistema alta"
  type    = "metric alert"
  message = "Carga (1m) de {{value}} en {{host.name}} (umbral 4). ${var.alert_notification}"
  query   = "avg(last_5m):avg:system.load.1{*} by {host} > 4"

  monitor_thresholds {
    warning  = 3
    critical = 4
  }

  notify_no_data    = true
  no_data_timeframe = 10
  renotify_interval = 60
  include_tags      = true
  tags              = local.monitor_tags
}

# 5) Host / agente caído (service check)
resource "datadog_monitor" "host_caido" {
  name    = "Host o agente Datadog caido"
  type    = "service check"
  message = "El agente Datadog no reporta en {{host.name}}. ${var.alert_notification}"
  query   = "\"datadog.agent.up\".over(\"*\").by(\"host\").last(2).count_by_status()"

  monitor_thresholds {
    warning  = 1
    critical = 1
    ok       = 1
  }

  notify_no_data    = true
  no_data_timeframe = 10
  renotify_interval = 60
  include_tags      = true
  tags              = local.monitor_tags
}
