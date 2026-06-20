# Prompts utilizados — Monitorización AWS + Datadog

Este documento recoge los prompts empleados para generar la infraestructura de
monitorización (integración AWS↔Datadog, dashboards y alertas) mediante Terraform.

---

## 1. Prompt — Integración AWS ↔ Datadog (Terraform)

> Contexto: proyecto "monitoring" con Terraform en `tf/`, provider `DataDog/datadog` ~> 3.0.
> El `tf/main.tf` ya tenía el provider de Datadog, la política IAM `DatadogPolicy` y un
> dashboard, pero faltaba el puente real entre AWS y Datadog.

```text
Completa la integración AWS↔Datadog en Terraform. Actualmente existe el provider de
Datadog, una política IAM DatadogPolicy y un dashboard, pero NO el recurso que conecta
AWS con Datadog. Crea en tf/datadog.tf:
- Un data "aws_caller_identity" para obtener el account id.
- El recurso datadog_integration_aws que registre la cuenta y genere el external_id.
- Un aws_iam_role "DatadogAWSIntegrationRole" asumible por la cuenta de AWS de Datadog
  (arn:aws:iam::464622532012:root) restringido por sts:ExternalId.
- El aws_iam_role_policy_attachment que adjunta la política DatadogPolicy a ese rol.
Explica luego cómo aplicarlo (exportar TF_VAR_datadog_* y terraform init/plan/apply).
```

---

## 2. Prompt — Dashboard completo (Terraform)

```text
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
- El comando para aplicarlo (cargar TF_VAR_datadog_* desde .env y terraform plan/apply
  en PowerShell, con -target al nuevo recurso).
- Verificación posterior vía API de Datadog (sitio EU) de que el dashboard se creó.
```

---

## 3. Prompt — Set de alertas / monitores (Terraform)

```text
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
   query con porcentaje usado real (1 - system.mem.usable/system.mem.total)*100,
   by {host}, warning 80 / critical 90.
3) Disco lleno:
   "avg(last_5m):avg:system.disk.in_use{...excluyendo /dev/loop*...} by {host,device} * 100 > 90",
   warning 80 / critical 90.
4) Carga del sistema alta:
   "avg(last_5m):avg:system.load.1{*} by {host} > 4", warning 3 / critical 4.
5) Host/Agente caído (service check):
   type "service check", query
   "\"datadog.agent.up\".over(\"*\").by(\"host\").last(2).count_by_status()".

Requisitos:
- Type correcto por alerta ("metric alert" para 1-4, "service check" para 5).
- Cada monitor con name claro en español y message útil con plantillas Datadog
  ({{host.name}}, {{value}}) y placeholder de notificación. Usa una VARIABLE de Terraform
  "alert_notification" (tipo string, default "") concatenada al final del message.
- Parámetros: notify_no_data = true, no_data_timeframe = 10, renotify_interval = 60,
  include_tags = true.
- Etiqueta todos los monitores con tags = ["project:lti", "managed-by:terraform"].
- HCL válido para el provider Datadog v3.x.

Entregable:
- Contenido completo de tf/monitors.tf (y la variable nueva).
- Comando para aplicar en Windows/PowerShell (cargar TF_VAR_datadog_* desde .env,
  terraform plan + apply con -target a los nuevos monitores).
- Verificación vía API de Datadog (sitio EU, /api/v1/monitor) listando nombres y estado.
```

---

## 4. Prompt — Instalación del agente Datadog (sin clave SSH)

> Contexto: la key pair `lti-key.pem` se había perdido (irrecuperable en AWS).

```text
Necesito instalar el agente Datadog v7 en una instancia EC2 Ubuntu (eu-north-1,
i-022fd37383692892e, IP 16.192.61.61) pero no tengo el .pem de la key pair. El puerto 22
está abierto. Usa EC2 Instance Connect para inyectar una clave SSH temporal y, dentro de
la ventana de validez, conéctate por SSH y ejecuta el instalador del agente apuntando al
sitio EU:
  DD_API_KEY=<key> DD_SITE="datadoghq.eu" bash -c "$(curl -L .../install_script_agent7.sh)"
Verifica después que el agente está activo y que el host reporta en Datadog (sitio EU).
```

---

### Notas sobre el uso de los prompts

- En todos los casos se aplicó con `terraform apply -target=<recurso>` para no tocar
  recursos ajenos (EC2/S3 de otro proyecto).
- Las variables sensibles (`TF_VAR_datadog_api_key`, `TF_VAR_datadog_app_key`,
  `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) se cargan desde `.env` (ignorado por git).
- El **sitio** correcto resultó ser **EU** (`api.datadoghq.eu`), no US5 como estaba al inicio.
