# Monitorización con AWS + Datadog (Terraform)

Documentación del trabajo de **observabilidad** del proyecto: integración AWS↔Datadog,
dashboards y alertas definidos como código (Terraform), más el agente Datadog instalado
en la instancia EC2.

- **Prompts utilizados** → ver [prompts/datadog-aws-prompts.md](prompts/datadog-aws-prompts.md)
- **Infraestructura** → carpeta [tf/](tf/)
- **Sitio Datadog**: EU (`https://app.datadoghq.eu`) · **Región AWS**: `eu-north-1`

---

## 1. Explicación de los cambios realizados

### 1.1 Configuración base del provider ([tf/main.tf](tf/main.tf))
- **Región AWS**: cambiada de `us-east-1` → **`eu-north-1`** (donde está la instancia real).
- **Sitio de Datadog**: cambiado de `api.us5.datadoghq.com` → **`api.datadoghq.eu`**
  (la cuenta está en la región EU).

### 1.2 Integración AWS ↔ Datadog ([tf/datadog.tf](tf/datadog.tf)) — *nuevo*
Faltaba el puente real que permite a Datadog leer métricas de CloudWatch. Se añadió:
- `datadog_integration_aws` — registra la cuenta AWS en Datadog y genera el `external_id`.
- `aws_iam_role` **DatadogAWSIntegrationRole** — rol que la cuenta de AWS de Datadog
  (`464622532012`) asume, protegido por `sts:ExternalId`.
- `aws_iam_role_policy_attachment` — adjunta la política `DatadogPolicy` (permisos de
  lectura de CloudWatch/EC2/Logs, ya definida en `main.tf`) al rol.

Resultado: en **Datadog → Integrations → AWS** aparece la cuenta `897689476680` y
empiezan a llegar las métricas `aws.ec2.*` de todas las instancias de la cuenta.

### 1.3 Dashboards
- **`ec2_dashboard`** (existente en `main.tf`): CPU + Network In/Out de EC2.
- **`full_monitoring`** ([tf/dashboard.tf](tf/dashboard.tf)) — *nuevo*, dashboard completo
  en 3 grupos:
  - **Resumen**: CPU, memoria y carga actuales (`query_value`).
  - **Host (agente)**: CPU por estado, memoria usada/total, disco, red y carga 1/5/15m.
  - **EC2 (CloudWatch)**: CPU, Network In/Out y status checks.
  - URL: `https://app.datadoghq.eu/dashboard/<id>`

### 1.4 Alertas / monitores ([tf/monitors.tf](tf/monitors.tf)) — *nuevo*
Cinco `datadog_monitor`, todos etiquetados `project:lti`, `managed-by:terraform`:

| Monitor | Tipo | Warning / Critical |
|---------|------|--------------------|
| CPU alta en host | metric alert | 70% / 85% |
| Memoria alta en host | metric alert | 80% / 90% (memoria real, descuenta caché) |
| Disco lleno en host | metric alert | 80% / 90% (excluye dispositivos `loop` de snap) |
| Carga del sistema alta | metric alert | 3 / 4 |
| Host / agente caído | service check | `datadog.agent.up` |

El destino de notificación es parametrizable con la variable `alert_notification`
(define `TF_VAR_alert_notification="@correo"` en `.env` para recibir avisos).

### 1.5 Agente Datadog en la instancia
- Agente **v7** instalado en la instancia EC2 Ubuntu `i-022fd37383692892e` (eu-north-1),
  configurado con `site: datadoghq.eu`.
- Aporta métricas de host/proceso (`system.*`) que la integración de CloudWatch no da.

### 1.6 Saneamiento de credenciales y entorno (soporte)
- `.gitignore` corregido para ignorar `**/.env`, `*.tfstate*` y `*.tfvars`.
- Secretos eliminados del historial de git y credenciales rotadas.
- `schema.prisma` pasó a usar `env("DATABASE_URL")` en vez de credenciales hardcodeadas.
- `.env.example` documentando las variables necesarias.

---

## 2. Cómo aplicar la infraestructura

Requisitos: **Terraform** y **AWS CLI** instalados; variables en `.env`
(`TF_VAR_datadog_api_key`, `TF_VAR_datadog_app_key`, `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`).

```powershell
# Cargar variables del .env en la sesión de PowerShell
Get-Content ..\.env | Where-Object { $_ -match '^\s*[^#].*=' } | ForEach-Object {
  $kv = $_ -split '=', 2; Set-Item -Path "env:$($kv[0].Trim())" -Value $kv[1].Trim().Trim('"')
}

cd tf
terraform init
terraform plan
terraform apply        # o con -target=<recurso> para aplicar selectivamente
```

> Se usa `-target` para aplicar solo los recursos de Datadog y **no** crear la EC2/S3
> definidas en el código (que pertenecen a otro proyecto / ya no existen).

---

## 3. Desafíos encontrados y cómo se resolvieron

### 3.1 La API key de Datadog daba 403
**Problema**: el valor en `.env` era el **Key ID** (un UUID con guiones), no el valor real
de la clave (32 caracteres hex). Daba `403 Forbidden` en todas las llamadas.
**Solución**: copiar el **valor** real de la API key desde Datadog (no el Key ID) y
sustituirlo en `.env`. Verificado con `/api/v1/validate`.

### 3.2 Sitio de Datadog incorrecto (US5 vs EU)
**Problema**: el provider apuntaba a `api.us5.datadoghq.com`, pero la cuenta está en EU.
Validando la API key contra todos los sitios, **solo `datadoghq.eu` devolvía `valid=true`**.
**Solución**: cambiar `api_url` a `https://api.datadoghq.eu` y usar `site: datadoghq.eu`
en el agente.

### 3.3 Región AWS y state obsoleto
**Problema**: el Terraform apuntaba a `us-east-1` y su `terraform.tfstate` referenciaba
2 instancias que **ya no existían**; la instancia real corría en `eu-north-1` y **no
estaba gestionada por este Terraform** (es del proyecto *pipeline*, creada a mano).
Aplicar tal cual habría **duplicado infraestructura** en Virginia.
**Solución**: cambiar la región a `eu-north-1`, **apartar el state obsoleto** (backup) y
empezar limpio, y aplicar **solo los recursos de Datadog** con `-target` (sin recrear
EC2/S3 ajenas).

### 3.4 Clave SSH (`.pem`) perdida
**Problema**: no se podía entrar a la instancia para instalar el agente; la clave privada
de una key pair de EC2 **no es recuperable**. La instancia tampoco estaba gestionada por
SSM (sin rol IAM).
**Solución**: usar **EC2 Instance Connect** para inyectar una clave SSH temporal (válida
60 s) y, dentro de esa ventana, conectarse e instalar el agente con el script oficial.

### 3.5 Falsas alarmas en las alertas de disco y memoria
**Problema**: tras crear los monitores, "Disco lleno" y "Memoria alta" saltaron en rojo.
- Disco: los dispositivos `/dev/loop0..3` (paquetes **snap** de Ubuntu, squashfs de solo
  lectura) están **siempre al 100%**.
- Memoria: `system.mem.used` incluye **caché reutilizable**, inflando el % (94%).
**Solución**: excluir los `loop*` en la query de disco y usar
`(1 - system.mem.usable/system.mem.total)*100` para la memoria real (resultó 52%).
Ambos monitores pasaron a **OK**.

### 3.6 Conflicto de puerto de PostgreSQL (entorno de desarrollo)
**Problema**: el contenedor `db` no publicaba el `5432` porque otro Postgres lo ocupaba;
Prisma fallaba con `P1000` al conectar a la BD equivocada.
**Solución**: mover la BD del proyecto al puerto **`5434`** (`.env`, `schema.prisma`) y
recrear el contenedor.

### 3.7 Recurso de Terraform deprecado
**Observación**: `datadog_integration_aws` está marcado como deprecado a favor de
`datadog_integration_aws_account` en versiones recientes del provider. Funciona
(solo emite *warnings*); queda como mejora futura migrarlo.
