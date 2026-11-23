# Liberación y despliegue continuo: SaaS Veterinaria

## Caso de estudio y alcance

SaaS Veterinaria es una aplicación web Next.js 16/React 19 con TypeScript. La interfaz se despliega en Vercel y consume Supabase para autenticación y datos PostgreSQL protegidos con Row Level Security (RLS). Una liberación defectuosa puede interrumpir el acceso de clínicas y exponer información entre tenants; por eso cada cambio se valida antes de producción y las migraciones de base de datos no se ejecutan automáticamente desde el pipeline.

La automatización usa GitHub Actions como herramienta CI/CD, GitHub Environment `production` para controlar el despliegue y Vercel CLI para vincular el pipeline con el proyecto de producción. La URL actual de producción es `https://saa-s-veterinaria.vercel.app/`.

## Justificación del flujo de trabajo

1. Los cambios se desarrollan en ramas `feature/*` y se integran en `dev`; la liberación se realiza fusionando `dev` en `main`, siguiendo la estrategia documentada en el README.
2. Cada Pull Request hacia `dev` o `main` ejecuta `npm ci`, ESLint y una compilación de Next.js con valores ficticios para las variables públicas de Supabase. Esto valida el código sin usar secretos de producción.
3. Al actualizar `main` (o ejecutar manualmente el workflow), un trabajo separado protegido por el entorno `production` obtiene la configuración del proyecto Vercel, repite lint y genera el artefacto con `vercel build --prod`.
4. El pipeline publica el artefacto ya construido (`vercel deploy --prebuilt --prod`) y valida que la URL de producción responda correctamente.
5. Si falla cualquier etapa, la ejecución queda fallida y la liberación no se considera satisfactoria. Las migraciones de Supabase requieren revisión/aplicación controlada y respaldo independiente.

La separación entre validación de PR y publicación evita exponer credenciales a PRs de forks. El artefacto de producción se construye con el entorno del proyecto Vercel, no con credenciales simuladas.

## Entorno requerido

### CI en GitHub Actions

- Runner `ubuntu-latest`.
- Node.js 22, npm y `curl`.
- Dependencias instaladas desde `frontend/package-lock.json` mediante `npm ci`.
- GitHub Actions habilitado y permiso de lectura del repositorio; el trabajo de producción también necesita permiso de despliegues.
- Entorno de GitHub llamado `production`, idealmente con aprobación de un responsable y restricción a la rama `main`.

### Despliegue en Vercel

- Proyecto Vercel vinculado al repositorio y con framework Next.js.
- Variables de entorno configuradas en Vercel para Production: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` y, si las Server Actions administrativas lo requieren, `SUPABASE_SERVICE_ROLE_KEY`.
- El token Vercel debe tener acceso únicamente al proyecto/equipo requerido.
- La aplicación debe estar publicada en la URL asociada con `PRODUCTION_URL`.
- Los secretos `VERCEL_TOKEN`, `VERCEL_ORG_ID` y `VERCEL_PROJECT_ID` se guardan en GitHub Environment `production`; nunca se incluyen en el repositorio. `PRODUCTION_URL` se registra como variable no secreta del mismo entorno.

El workflow crea el enlace temporal `.vercel/project.json` desde los IDs protegidos y ejecuta `vercel pull` para obtener las variables de producción. El directorio `.vercel` y los archivos `.env*` están ignorados por Git.

## Niveles de servicio propuestos

Estos objetivos son una propuesta inicial para el caso académico, no un acuerdo operativo ya firmado. Deben confirmarse con quien administre Vercel, Supabase y el servicio veterinario antes de presentarlos como SLA contractual.

| Indicador | Objetivo inicial | Medición / respuesta |
|---|---:|---|
| Disponibilidad web mensual | >= 99.5% | Comprobación HTTP cada 5 minutos; excluir mantenimiento anunciado |
| Latencia de solicitudes web | p95 < 2.5 s | Métrica de rendimiento de Vercel; revisar tendencias semanalmente |
| Errores HTTP 5xx | < 1% de solicitudes mensuales | Vercel Runtime Logs; investigar picos y regresiones tras despliegue |
| Recuperación (RTO) | <= 4 horas | Revertir el despliegue Vercel y restaurar servicio |
| Pérdida máxima de datos (RPO) | <= 24 horas | Depende del plan y política de respaldo/restauración de Supabase; verificarlo con el proveedor |
| Recuperación de una liberación | <= 15 minutos para iniciar rollback | Revertir alias/despliegue en Vercel y verificar con smoke test |

El pipeline no configura por sí solo monitoreo externo ni políticas de respaldo. Estos objetivos deben revisarse mensualmente y ante cambios en el plan de los proveedores.

## Métricas de monitoreo

| Métrica | Fuente sugerida | Umbral / acción |
|---|---|---|
| Disponibilidad y código HTTP de `/` | Monitor HTTP (intervalo 5 min) y smoke test de Actions | Alerta tras 2 fallos consecutivos; el smoke test fallido bloquea el éxito de la ejecución |
| Latencia p50/p95 y Web Vitals | Vercel Observability / Speed Insights, si se habilitan | Investigar p95 >= 2.5 s |
| Tasa HTTP 5xx y errores de Runtime | Vercel Runtime Logs / Observability | Investigar si 5xx >= 1% durante 5 min |
| Resultado y duración de CI/despliegues | Historial de GitHub Actions | Investigar cualquier fallo o aumento persistente de la duración |
| Errores de Auth, consultas, conexiones y recursos de PostgreSQL | Supabase Logs, métricas y alertas del proyecto | Revisar picos de errores, saturación y eventos de acceso denegado |
| Integridad de aislamiento entre clínicas | Pruebas SQL de RLS en `supabase/tests/database` | Ejecutar en ambiente de prueba antes de modificar políticas o esquema |

Los dashboards de Vercel/Supabase y alertas externas dependen de habilitación y plan del proveedor; el repositorio no incluye claves de monitorización ni afirma que esas alertas ya estén activas.

## Parámetros de configuración

| Herramienta | Parámetro | Valor / uso |
|---|---|---|
| GitHub Actions | Trigger de validación | PR a `dev` y `main` |
| GitHub Actions | Trigger de producción | Push a `main` o ejecución manual |
| GitHub Actions | Runner / Node | `ubuntu-latest` / Node.js `22` |
| GitHub Actions | Instalación | `npm ci` con `frontend/package-lock.json` |
| GitHub Actions | Entorno protegido | `production`; despliegue serializado, sin cancelar una liberación activa |
| GitHub Environment | Secretos | `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID` |
| GitHub Environment | Variable | `PRODUCTION_URL`, URL canónica HTTPS de producción |
| Vercel CLI | Versión / pull / build / deploy | `66.6.0`; `pull --environment=production`, `build --prod`, `deploy --prebuilt --prod` |
| Aplicación | Runtime | Next.js standalone; Node.js 22 en CI |
| Supabase | Variables de entorno | URL y anon key públicas; service-role solo como secreto server-side cuando sea necesario |
| Smoke test | Reintentos | 5 reintentos, 5 s entre intentos, timeout de 30 s; falla ante respuesta HTTP no exitosa |

## Estructura entregada

- `.github/workflows/release.yml`: pipeline de validación, liberación y despliegue.
- `scripts/release/prepare-vercel.sh`: genera el enlace de entorno de liberación y descarga la configuración de producción.
- `scripts/release/test-release.sh`: ejecuta lint y construye el artefacto de producción para Vercel.
- `scripts/release/deploy-vercel.sh`: publica el artefacto ya construido.
- `scripts/release/smoke-test.sh`: verifica el endpoint de producción tras la publicación.

## Puesta en marcha

1. En GitHub, crea el Environment `production`; limita sus despliegues a `main` y añade aprobación requerida si corresponde.
2. Registra en ese Environment los tres secretos Vercel y la variable `PRODUCTION_URL`.
3. En Vercel, confirma que el proyecto corresponde a esta aplicación y que las variables de entorno de producción de Supabase están configuradas.
4. Protege `main` para requerir que pase el workflow `Validate application` antes de fusionar.
5. Abre un PR a `dev` para comprobar CI; tras integrar cambios en `main`, verifica la publicación y el smoke test. La primera ejecución real depende de los IDs/token y reglas del proyecto Vercel y GitHub, que no se guardan en el repositorio.
