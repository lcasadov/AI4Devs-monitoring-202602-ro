Contexto del proyecto:
- Repositorio de "monitoring" con infraestructura Terraform en la carpeta tf/.
- Provider Datadog: source "DataDog/datadog", versión ~> 3.0.
- La cuenta de Datadog está en el sitio EU (provider con api_url "https://api.datadoghq.eu").
- Hay una integración AWS↔Datadog activa y un agente Datadog v7 instalado en una
  instancia EC2 Ubuntu en eu-north-1 (instance_id i-022fd37383692892e, tag Name "lti-pipeline").
- Ya existen dashboards definidos por Terraform (tf/main.tf y tf/dashboard.tf).
- El provider y las variables datadog_api_key / datadog_app_key ya están declarados en main.tf.

Objetivo:
Crear un archivo NUEVO tf/monitors.tf con un set de alertas (recursos datadog_monitor)
para vigilar la salud del host y de la instancia EC2. No tocar ningún otro archivo.

Set de alertas a crear (recurso datadog_monitor cada una):
1) CPU alta (host, agente):
   query "avg(last_5m):avg:system.cpu.user{*} by {host} > 85", warning 70 / critical 85.
2) Memoria alta:
   query con porcentaje usado: avg(last_5m): (system.mem.used / system.mem.total * 100),
   by {host}, warning 80 / critical 90.
3) Disco lleno:
   "avg(last_5m):avg:system.disk.in_use{*} by {host,device} > 90", warning 80 / critical 90.
4) Carga del sistema alta:
   "avg(last_5m):avg:system.load.1{*} by {host} > 4", warning 3 / critical 4.
5) Host/Agente caído (service check):
   type "service check", query
   "\"datadog.agent.up\".over(\"*\").by(\"host\").last(2).count_by_status()",
   con bloque monitor_thresholds { ok=1 warning=1 critical=1 } o equivalente para "service check".

Requisitos:
- Type correcto por alerta ("metric alert" para 1-4, "service check" para 5).
- Cada monitor con name claro en español y message útil con plantillas Datadog
  ({{host.name}}, {{value}}) y placeholder de notificación. Usa una VARIABLE de Terraform
  "alert_notification" (tipo string, default "") y concaténala al final del message
  para poder poner @email o @slack sin editar cada monitor.
- Parámetros razonables: notify_no_data = true, no_data_timeframe = 10,
  renotify_interval = 60, include_tags = true.
- Etiqueta todos los monitores con tags = ["project:lti", "managed-by:terraform"].
- HCL válido para el provider Datadog v3.x.
- No declarar de nuevo el provider ni las variables existentes; sí añadir la nueva
  variable "alert_notification" (en tf/monitors.tf o variables.tf).

Entregable:
- Contenido completo de tf/monitors.tf (y la variable nueva).
- Comando para aplicar en Windows/PowerShell: cargar TF_VAR_datadog_* desde .env y
  ejecutar terraform plan + apply, usando -target a los nuevos datadog_monitor para no
  tocar el resto.
- Verificación posterior vía API de Datadog (sitio EU, endpoint /api/v1/monitor) de que
  los monitores se crearon, listando sus nombres y estado.