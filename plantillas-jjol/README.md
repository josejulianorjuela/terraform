# plantillas-jjol

Plantillas de infraestructura como código para Terraform u OpenTofu (≥ 1.8), seguras por defecto, en Azure, AWS,
Google Cloud, OCI y Kubernetes. Cada plantilla es un módulo normal por nube, sin motor de plantillas: se llenan las
variables (por ejemplo en `terraform.tfvars.json`) y se aplica.

```
<plantilla>/template.json        catálogo: entradas, tamaños, costos estimados, salidas y recursos principales
<plantilla>/<nube>/versions.tf   versión de Terraform, proveedores y bloque provider (sin backend)
<plantilla>/<nube>/variables.tf  variables comunes + las de la plantilla
<plantilla>/<nube>/main.tf
<plantilla>/<nube>/outputs.tf
```

| Plantilla | Nubes | Qué crea |
|---|---|---|
| `red-base` | azure, aws, gcp, oci | VNet/VPC/VCN, subredes privadas (y públicas), NSG/SG/firewall/security lists cerrados desde Internet, NAT, flow logs (AWS, GCP, OCI) |
| `app-contenedores` | azure, aws, gcp, oci | Container Apps + ACR + Log Analytics + identidad · App Runner + ECR + roles · Cloud Run v2 + Artifact Registry + cuenta de servicio · Container Instances (+ OCIR opcional) |
| `app-kubernetes` | kubernetes | Deployment no root con raíz de solo lectura y límites, Service, HPA, PDB, NetworkPolicy, Ingress con TLS opcional |
| `base-datos` | azure, aws, gcp, oci | PostgreSQL Flexible privado (solo Entra ID) · RDS cifrado (Multi-AZ opcional) · Cloud SQL con IP privada, copias y PITR · OCI Database with PostgreSQL |
| `serverless` | azure, aws, gcp, oci | Functions Flex Consumption + Storage + cola · Lambda + SQS + rol · Cloud Run functions + Pub/Sub · OCI Functions + Streaming + Connector Hub |

Proveedores: azurerm ~> 5.0, aws ~> 6.0, google ~> 8.0, oci ~> 9.0, kubernetes ~> 3.0, archive ~> 2.7.

## Uso

```bash
cd base-datos/aws
cat > terraform.tfvars.json <<'EOF'
{ "name": "pedidos", "environment": "dev", "team": "plataforma", "requester": "ana", "region": "us-east-1",
  "subnet_ids": "subnet-aaa,subnet-bbb" }
EOF
terraform init
terraform plan
```

Los módulos no traen bloque `backend`: agregue un `backend.tf` o use `terraform init -backend-config=...` según su entorno.

## Variables comunes

Todo módulo acepta:

- `name` (minúsculas, números y guiones, 3 a 24), `environment` (`dev`, `test` o `prod`), `team`, `requester`, `tags` (`map(string)`).
- Ubicación: azure `subscription_id`, `location`, `resource_group_name` (vacío: crea `rg-<name>-<environment>`);
  aws `region`; gcp `project_id`, `region`; oci `compartment_id`, `region`; kubernetes `kubeconfig_path`, `kube_context`, `namespace`.
- Las entradas de `template.json` y las variables del tamaño elegido (`sizes.<tamaño>.vars`).

Etiquetas de todo recurso: `merge(var.tags, {team, environment, requester, "managed-by" = "plantillas-jjol"})`
(en GCP y Kubernetes, saneadas como labels). En `prod` se activan la protección contra borrado y las copias
geo-redundantes donde aplica.

## template.json

- `inputs[]`: `name`, `label`, `type` (`string|number|bool|select`), `default`, `required`, y opcionales `pattern`,
  `options`, `min`, `max`, `help` y `providers` (limita la entrada a ciertas nubes).
- `sizes`: `pequeno`, `mediano`, `grande`, con `label`, `vars` y `monthly` (USD estimados por nube).
- `outputs[]`: `name`, `label`, `kind` (`url|text`); todo módulo de la plantilla declara esas salidas.
- `demo.<nube>[]`: recursos principales del módulo con sus atributos de seguridad (`type`, `name`, `values`,
  `unknown`, `refs`), para simular un plan sin ejecutar Terraform. En `values`, `{{x}}` se reemplaza por la entrada,
  la variable del tamaño, `tags`, `labels` o `is_prod`.

## Validar

```bash
for d in */*/; do (cd "$d" && terraform init -backend=false -input=false >/dev/null && terraform validate); done
```

## Licencia

Apache 2.0.
