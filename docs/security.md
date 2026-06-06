# Seguridad

Gentle Starter está pensado como base de desarrollo local. Antes de
publicar un repo derivado, revisá que no incluya secretos, credenciales ni
estado local del entorno.

## Archivos que no deben publicarse

No commitees:

```text
.env
env/
.pi/
.atl/
```

Estos paths pueden contener configuración local, bases de datos, sesiones,
credenciales o estado generado por herramientas de desarrollo asistido.

## `.env` y `.env.example`

Usá `.env.example` como plantilla versionada:

```bash
cp .env.example .env
```

Reglas:

- `.env.example` debe contener solo valores seguros o placeholders.
- `.env` debe quedarse local y no versionarse.
- No agregues tokens reales, contraseñas, claves privadas ni credenciales de
  servicios externos a archivos versionados.

## Estado local en `env/`

El directorio `env/` se usa para persistir estado local montado en el
contenedor, por ejemplo:

```text
env/.pi/
env/.engram/
env/.gitconfig/
```

Ese contenido pertenece a la máquina del desarrollador. No debe publicarse ni
copiarse entre proyectos sin revisión.

## Docker-in-Docker y permisos elevados

El devcontainer usa Docker-in-Docker y permisos elevados:

```yaml
privileged: true
```

```json
"runArgs": ["--privileged"]
```

Esto puede ser útil para flujos que necesitan Docker dentro del contenedor, pero
incrementa el nivel de acceso del entorno. Usalo solo en máquinas y proyectos
donde ese riesgo sea aceptable.

Si tu proyecto no necesita Docker dentro del devcontainer, evaluá quitar:

- `ghcr.io/devcontainers/features/docker-in-docker:3`;
- `privileged: true` en `.devcontainer/docker-compose.yml`;
- `--privileged` en `.devcontainer/devcontainer.json`.

## Git y GitHub

El contenedor puede montar configuración local de Git en:

```text
env/.gitconfig/
```

Antes de publicar, revisá que no haya credenciales o tokens en:

```text
env/.gitconfig/config
env/.gitconfig/.git-credentials
```

Si usás `gh auth login`, tratá los tokens generados como secretos locales.

## Engram y memoria local

Engram puede guardar información persistente del trabajo realizado. Revisá su
base local antes de compartir un entorno o copiar `env/`:

```text
env/.engram/
```

Puede contener decisiones, contexto del proyecto, prompts, resúmenes o datos
sensibles mencionados durante el desarrollo.

## Checklist antes de publicar

```bash
# Ver cambios y archivos no versionados
git status --short

# Buscar términos sensibles comunes
git grep -n "TOKEN\|SECRET\|PASSWORD\|PRIVATE_KEY\|API_KEY" || true

# Verificar que el entorno base siga consistente
task doctor
```

Revisá manualmente cualquier archivo nuevo antes de commitear, especialmente si
viene de `env/`, `.pi/`, `.atl/` o configuraciones locales.

## Reportar problemas

Si encontrás un problema de seguridad en este starter, abrí un issue privado o
contactá al mantenedor del repo antes de publicar detalles sensibles.
