Contexto del proyecto:
- Repositorio de "monitoring" con infraestructura Terraform en la carpeta tf/.
- Provider Datadog: source "DataDog/datadog", versión ~> 3.0.
- La cuenta de Datadog está en el sitio EU (api_url = "https://api.datadoghq.eu").
- Hay una integración AWS↔Datadog ya activa y un agente Datadog v7 instalado en
  una instancia EC2 Ubuntu en la región eu-north-1 (instance_id i-022fd37383692892e,
  tag Name "lti-pipeline").
- Ya existe un recurso datadog_dashboard.ec2_dashboard básico en tf/main.tf con 3
  widgets (CPU, Network In, Network Out) usando métricas aws.ec2.*.

Objetivo:
Crear en el archivo tf/dashboard.tf (ahora vacío) un NUEVO recurso
datadog_dashboard llamado "full_monitoring" más completo, sin tocar el existente.

Requisitos del dashboard:
- title: "LTI - Full Monitoring", layout_type = "ordered".
- Organizar los widgets en bloques group_definition:
  1) Grupo "Resumen": widgets query_value con la CPU actual (avg:system.cpu.user),
     memoria usada (system.mem.used) y carga (system.load.1).
  2) Grupo "Host (agente)": timeseries de:
     - CPU por estado (system.cpu.user, system.cpu.system, system.cpu.idle) by {host}
     - Memoria usada vs total (system.mem.used, system.mem.total)
     - Disco en uso (system.disk.in_use) by {host,device}
     - Red host (system.net.bytes_rcvd, system.net.bytes_sent)
     - Carga del sistema (system.load.1, system.load.5, system.load.15)
  3) Grupo "EC2 (CloudWatch)": timeseries de aws.ec2.cpuutilization,
     aws.ec2.network_in, aws.ec2.network_out, aws.ec2.status_check_failed,
     todas by {instance_id}.
- Usa display_type "line" o "area" donde tenga sentido y pon títulos claros en español.

Restricciones técnicas:
- HCL válido para el provider Datadog v3.x (sintaxis de bloques widget {
  timeseries_definition { request { q = "..." } } }, group_definition con
  widget anidados, query_value_definition con request { q } y aggregator).
- No declares de nuevo el provider ni las variables (ya están en main.tf).
- No crees recursos AWS ni dupliques el dashboard existente.
- Deja comentarios breves explicando cada grupo.

Entregable:
- El contenido completo del archivo tf/dashboard.tf.
- El comando para aplicarlo: cómo cargar las variables TF_VAR_datadog_* desde .env
  y ejecutar terraform plan + terraform apply (entorno Windows/PowerShell), idealmente
  con -target al nuevo recurso para no tocar nada más.
- Verificación posterior vía API de Datadog (sitio EU) de que el dashboard se creó.