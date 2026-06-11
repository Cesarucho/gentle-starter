# Extender el proyecto

Esta es la guía comprehensiva para añadir nueva funcionalidad al
devcontainer. Cubre los tres sistemas que componen una nueva
contribución, los conecta con un ejemplo práctico, y responde las
preguntas que surgen con más frecuencia.

Los tres sistemas son:

1. **[El árbol de instalación](install-tree.md)** — scripts en
   build-time que instalan herramientas y dependencias durante la
   construcción de la imagen.
2. **[El contrato de volúmenes](install-volumes.md)** — bind
   mounts declarados en `docker-compose.yml` que el hook postCreate
   re-puebla ejecutando los scripts de instalación que son dueños
   de cada target.
3. **[Siembra de configuraciones](configs.md)** — archivos de
   configuración base versionados en
   `.devcontainer/<name>-config/` y copiados a su path de runtime
   en la primera ejecución.

Cada sistema tiene su propio documento de análisis en
profundidad. Este archivo es el punto de entrada y la FAQ. Si
solamente tenés tiempo de leer un documento, leé este.

## Los tres sistemas en un diagrama

```text
   FASE DE BUILD (Dockerfile)              FASE DE RUNTIME (setup.sh)
   ───────────────────────                ────────────────────────
   for group in 01-core 02-enabled 03-hooks:
       find each *.sh in group      ──▶  setup_versioned_pi_config
       DEVCONTAINER_PHASE=build            seed_config_tree
       bash "${script}"                     (pi-config -> ~/.pi)
                                       ──▶ setup_pi_workspace_trust
                                           git config wiring
                                       ──▶ repair_installed_volumes
                                           yq docker-compose.yml
                                           for each bind mount target,
                                              run owning script with
                                              DEVCONTAINER_PHASE=runtime
```

El mismo script de instalación puede correr dos veces en la vida
de un container: una en el build (para instalar la herramienta
globalmente) y otra en el postCreate (si su volumen target está
vacío o su config target no existe). El guard de idempotencia al
inicio del cuerpo decide si cada llamada es no-op o realmente
hace trabajo.

## Ejemplo práctico: añadir Redis como herramienta de desarrollo

Estás trabajando en un proyecto que usa Redis para caché. Querés
`redis-cli` disponible en cada rebuild, un `redis.conf` base que
puedas versionar, y que los datos sobrevivan a través de los
rebuilds. Esto toca los tres sistemas.

### Paso 1: install — `install/available/30-tool-redis.sh`

El script descarga e instala los paquetes de redis vía apt. Se
salta a sí mismo si redis ya está presente.

```bash
#!/usr/bin/env bash
# 30-tool-redis.sh — install redis-server and redis-cli.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

if devcontainer_has_cmd redis-cli && devcontainer_has_cmd redis-server; then
    devcontainer_log_info "redis already installed: $(redis-cli --version)"
    exit 0
fi

devcontainer_log_info "Installing redis"
devcontainer_run_as_root apt-get update
devcontainer_run_as_root apt-get install -y --no-install-recommends \
    redis-server redis-tools

devcontainer_log_info "redis installed: $(redis-cli --version)"
```

Activalo para activación por defecto:

```bash
cd .devcontainer/install/02-enabled
ln -sfn ../available/30-tool-redis.sh 30-tool-redis.sh
```

### Paso 2: config — `.devcontainer/redis-config/redis.conf`

Creá la fuente versionada:

```text
.devcontainer/redis-config/redis.conf
#   runtime: /etc/redis/redis.conf
```

Cablealo en `.devcontainer/setup.sh`:

```bash
setup_versioned_pi_config() {
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/pi-config" "${HOME}/.pi"
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/redis-config" "/etc/redis"
}
```

El helper `seed_config_tree` detecta que `/etc/redis` está fuera
de `$HOME` y escala a `sudo` para `cp` y `mkdir` automáticamente —
sin flag, sin cableado extra de tu parte.

### Paso 3: volume — bind mount + mapeo de reparación

En `docker-compose.yml`:

```yaml
volumes:
  - ../env/.redis:/var/lib/redis
```

En `compose_target_to_install_scripts` de `setup-volumes.sh`:

```bash
"${HOME}/.redis" | "/var/lib/redis")
    scripts_ref+=("30-tool-redis")
    ;;
```

### Paso 4: verificar

```bash
task install:list          # muestra 30-tool-redis en 02-enabled
task install:volumes       # muestra ../env/.redis -> /var/lib/redis propiedad de 30-tool-redis
task container:rebuild     # construye con los tres cambios

# dentro del container:
which redis-cli             # /usr/bin/redis-cli
redis-cli --version         # 7.x.x
cat /etc/redis/redis.conf | head -3   # el baseline versionado (copiado)
ls /var/lib/redis            # directorio de datos, persiste entre rebuilds
```

Los tres sistemas están ahora cableados juntos. Rebuilds futuros
preservan tus personalizaciones en `/etc/redis/redis.conf` y en el
directorio de datos, y el hook postCreate re-siembra cualquier
cosa que haya sido borrada.

## FAQ

### ¿Cómo añado un nuevo script de instalación?

Copiá `.devcontainer/install/templates/install-script.sh` a
`.devcontainer/install/available/NN-categoria-tool.sh`, llená las
secciones de variables, instalación y verificación, y linkeá desde
`02-enabled/` si debería estar activo por defecto. Consultá
[install-tree.md](install-tree.md) para la convención completa.

### ¿Cómo añado un nuevo volumen con estado?

Tres cosas tienen que coincidir (en diferentes archivos, por
cierto):

1. El bind mount en sí: declarado en
   `.devcontainer/docker-compose.yml` bajo
   `services.container-svc.volumes:`.
2. El mapeo target-a-script: un case en
   `compose_target_to_install_scripts` en
   `.devcontainer/setup-volumes.sh`.
3. El script de instalación (que también corre en runtime cuando
   el volumen está vacío): en
   `.devcontainer/install/available/`, opcionalmente linkeado desde
   `02-enabled/`.

Ejecutá `task install:volumes` después de editar el case para
verificar que el contrato está en sincronía. Consultá
[install-volumes.md](install-volumes.md) para la referencia en
profundidad.

### ¿Cómo añado la configuración base de una nueva herramienta?

Creá un directorio `.devcontainer/<name>-config/` con el árbol
de archivos que mirrorea la ubicación de la config de runtime
de la herramienta. Añadí una llamada a `seed_config_tree` en
`setup_versioned_pi_config` en `setup.sh`. Los targets fuera de
`$HOME` se manejan automáticamente (el helper escala a `sudo`).
Consultá [configs.md](configs.md) para la referencia en
profundidad.

### ¿Cómo mantengo mis cambios personales fuera de git?

Dos patrones:

- **Bind mounts en `env/`**: `env/` está en `.gitignore`. Cualquier
  cosa que dropees en `env/.pi/`, `env/.engram/`, etc. es por-clon
  y no se commitea.
- **Fuentes de config personales**: usá un sufijo
  `<name>-config.local/`; el patrón `*-config.local/` está en
  `.gitignore`. Dropeá tus archivos ahí, añadí una llamada a
  `seed_config_tree` con `|| true` a `setup_versioned_pi_config`, y
  la línea es inofensiva incluso si el directorio aún no existe.

### ¿Por qué mis archivos en `install/` cambian a mode 0755?

El workspace está bind-mounteado al devcontainer, así que el
`chmod 0755 ./.devcontainer-install -type f -name "*.sh"` del
Dockerfile también afecta los archivos fuente en el host. La
convención del proyecto es `0755` para todos los scripts de
instalación en el árbol fuente (matching el chmod en la imagen),
y la tarea `task install:doctor` no marca el mode como falla. Si
ves que el mode se resetea entre builds, es lo esperado — es el
contrato del bind mount.

### ¿Cuál es la diferencia entre build y runtime?

`DEVCONTAINER_PHASE=build` es el valor que el Dockerfile pone
cuando corre cada script de instalación durante la construcción
de la imagen. La fase de build corre como root dentro de la
imagen; el script típicamente usa `apt-get install`, descarga
tarballs, y escribe en `/usr/local/`.

`DEVCONTAINER_PHASE=runtime` es el valor que `setup.sh` pone
cuando re-corre el script de instalación en postCreate, ya sea
vía `setup_versioned_pi_config` (para archivos de config) o vía
`repair_installed_volumes` (para bind mounts con estado). La fase
de runtime corre como ubuntu; el script típicamente hace
instalaciones user-scoped (`npm install -g` para ubuntu,
`~/.local/bin/` para Engram, etc.) o se salta entero si la
herramienta ya está instalada.

Un script puede ser el mismo para ambas fases, con el guard de
idempotencia al inicio haciendo la diferencia un no-op cuando la
herramienta ya está. O un script puede ramificar por la fase:

```bash
if devcontainer_is_build; then
    devcontainer_log_info "Skipping user-scoped step during image build"
    exit 0
fi
# runtime-only install steps here
```

`30-ai-pi-gentle.sh` y `30-ai-engram.sh` son ejemplos reales de
este patrón.

### ¿Qué pasa si borro `env/` y rebuilda?

El contrato de volume-repair se activa. Con `env/.pi/` vacío,
`repair_installed_volumes` nota que el target está vacío y
re-corre `30-ai-pi-coding.sh` y `30-ai-pi-gentle.sh` con
`DEVCONTAINER_PHASE=runtime`. Los guards de idempotencia de los
scripts deciden qué se hace realmente (típicamente "nada, los
binarios ya están instalados, pero los paquetes npm y el
trust.json podrían necesitar toque").

Esto es lo mismo que pasa en un clon fresco: los bind mounts
aparecen vacíos, y el hook postCreate los puebla. El entorno de
desarrollo es "auto-curativo" respecto a los bind mounts con
estado, hasta el contrato de idempotencia de cada script de
instalación.

### ¿Cómo reseteo a los defaults del proyecto?

Para un archivo de config: `rm <target>/<file>` y luego rebuild.
El guard de `seed_config_tree` re-copia el baseline desde la
fuente versionada.

Para los datos de runtime de un volumen con estado: el contrato
de volume repair no resetea datos — eso es deliberado, para
evitar borrar accidentalmente tu trabajo. Si realmente querés un
slate limpio, renombrá `env/<vol>/` a `env/<vol>.bak` y rebuild.
El próximo startup verá un bind mount vacío y re-sembrará lo que
los scripts propietarios hagan en runtime.

Para todo el entorno: `docker system prune -a` (borra todas las
imágenes, builds y volúmenes) y `task container:rebuild` desde
cero. Martillo grande; usualmente solo necesitás uno de los
anteriores.

### ¿Por qué mis symlinks en `~/.pi/` siguen volviendo?

Si borraste el symlink y rebuildaste, pero un symlink fresco
apareció en el mismo path, estás en el comportamiento pre-`seed_config_tree`.
Desde el build actual, la función copia archivos reales, no
symlinks. Si aún ves symlinks, podés tener estado de un build
anterior; ejecutá
`docker exec code-run rm -f ~/.pi/agent/{settings,mcp}.json ~/.pi/gentle-ai/{banner,models,persona}.json`
para limpiar los symlinks legacy, y luego
`bash /home/ubuntu/code/.devcontainer/setup.sh` dentro del container.
Consultá la sección de migración en
[configs.md](configs.md) para el procedimiento completo.

### ¡La CLI de devcontainer no está en mi host!

Es una dependencia opcional, pero `task container:*` la usa.
Instalá con `sudo npm install -g @devcontainers/cli`. La tarea
`task doctor:host` (bajo el namespace `doctor:`, no `container:`)
la chequea y reporta un warning si falta; las tareas
`task container:*` fallan con "executable file not found in $PATH"
si la CLI no está.

## Ver también

- [install-tree.md](install-tree.md) — la convención de `install/` en profundidad
- [install-volumes.md](install-volumes.md) — el contrato de volume repair en profundidad
- [configs.md](configs.md) — siembra de configs en profundidad
- [`.devcontainer/README.md`](../../.devcontainer/README.md) — tour del directorio `.devcontainer/`
