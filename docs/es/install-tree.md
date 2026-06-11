# El árbol `install/`

El directorio `install/` bajo `.devcontainer/` es el catálogo de
scripts que ejecuta el build de Docker. El build itera tres grupos de
runtime en orden, cada uno ordenado por nombre de archivo. Este
documento explica la convención y cómo añadir un nuevo script de
instalación.

Para la vista comprehensiva (cómo interactúan `install/`, los
volúmenes y las configuraciones, además de un ejemplo práctico),
consulta [`docs/es/extending.md`](./extending.md).

## Estructura

```text
.devcontainer/install/
├── 01-core/                # obligatorio, corre en cada build
├── 02-enabled/             # symlinks a los scripts activos de available/
├── 03-hooks/               # extensiones del usuario (lee su README antes)
├── available/              # catálogo opt-in (numerados 00-99, sufijo .disabled)
├── lib/                    # helpers compartidos (common.sh)
└── templates/              # plantilla install-script.sh para scripts nuevos
```

## Los tres grupos de runtime

El loop de build del Dockerfile es:

```dockerfile
for group in 01-core 02-enabled 03-hooks; do
    find -L "./.devcontainer-install/${group}" -maxdepth 1 -type f -name "*.sh" \
        -not -name "*.disabled" \
        | sort | while read -r script; do
        DEVCONTAINER_PHASE=build bash "${script}"
    done
done
```

Tres cosas a notar:

- **El orden entre grupos está fijado por el Dockerfile**: `01-core/`
  corre primero, luego `02-enabled/`, luego `03-hooks/`. El prefijo
  numérico es una pista *visual* del orden de ejecución; el orden que
  realmente manda es el loop `for` del Dockerfile.
- **Dentro de cada grupo, los scripts se ordenan por nombre de
  archivo** (orden por defecto de `sort`). El prefijo numérico que
  pongas en cada script controla el orden intra-grupo. Así,
  `30-ai-engram.sh` corre después de `20-runtime-go.sh` dentro del
  mismo grupo.
- **`-L` sigue symlinks**, que es la forma en que `02-enabled/`
  (todos symlinks hacia `available/`) hace que los cuerpos de los
  scripts realmente se ejecuten.

### `01-core/` — siempre corre

Los cinco scripts del core hoy (00, 10, 15, 90, 99) cubren zona
horaria y locale, paquetes apt base, go-task, sudoers de ubuntu, y
limpieza final. Son obligatorios. Añadir un nuevo script al core
significa crear un archivo nuevo con el prefijo `NN-` correcto y
committearlo.

### `02-enabled/` — opt-in, activos por defecto

Cada entrada en `02-enabled/` es un symlink a un script en
`available/`. Los scripts activos por defecto (los 8 actuales: go,
java, node, pnpm, engram, pi-coding, pi-gentle, skills) están
linkeados aquí en tiempo de instalación. Para desactivar uno,
borrá el symlink. Para activar uno, ejecutá
`task install:enable -- NAME`.

### `03-hooks/` — extensiones del usuario (en .gitignore)

Reservado para extensiones personales, agnósticas al proyecto (un
instalador de cert de VPN personal, una CLI específica del sitio,
etc.). El directorio está vacío por defecto y viene con un README.
Consultá `install/03-hooks/README.md` para el contrato.

## `available/` — el catálogo

`available/` es el catálogo de scripts. Cada script en `available/`
es autocontenido, sin expectativa de estar habilitado. La
convención de numeración sigue los rangos por categoría del spec:

```text
00-09  pre-setup          (ej. 00-pre-apt.sh)
10-19  sistema base       (ej. 10-system.sh, 15-task.sh)
20-39  runtimes y AI      (ej. 20-runtime-go.sh, 30-ai-engram.sh)
40-49  CLI tools          (ej. 40-cli-mycli.sh)
50-79  presets opt-in     (ej. 50-browser-playwright.sh.disabled)
80-89  misc
90-98  post-setup         (ej. 90-post-setup-users.sh)
99     cleanup            (ej. 99-cleanup.sh)
```

El sufijo `.disabled` marca scripts que están en el catálogo pero
**no** habilitados por defecto. El filtro `find` del Dockerfile
(`-not -name "*.disabled"`) los excluye del loop de build. Para
optar-in, renombrá quitando el sufijo y linkeá desde `02-enabled/`.

## `lib/common.sh` — helpers compartidos

`lib/common.sh` proporciona 13 helpers que cualquier script de
instalación puede sourcear:

- `devcontainer_phase`, `devcontainer_is_build`, `devcontainer_is_runtime`
  — detección de fase
- `devcontainer_arch` — arquitectura normalizada (`amd64` / `arm64`)
- `devcontainer_has_cmd`, `devcontainer_has_path`,
  `devcontainer_skip_if_cmd`, `devcontainer_skip_if_path` — guards de idempotencia
- `devcontainer_fetch`, `devcontainer_verify_sha256` — descarga + integridad
- `devcontainer_run_as_root` — escalación de privilegios que es no-op cuando ya sos root
- `devcontainer_install_bin` — copia un binario a `/usr/local/bin`
- `devcontainer_log_info`, `devcontainer_log_warn`, `devcontainer_log_error` — logging

También tiene un guard de re-source, así que es seguro sourciarlo
desde cualquier script múltiples veces. Consultá el comentario de
cabecera en `lib/common.sh` para el contrato completo.

## `templates/install-script.sh` — la plantilla

`templates/install-script.sh` es el punto de partida canónico
para scripts nuevos. Tiene:

- shebang + `set -euo pipefail` (con un carve-out documentado para
  subshells de SDKMAN)
- un bloque `: "${VAR:=default}"` para defaults de variables
- un guard de idempotencia usando `devcontainer_has_cmd`
- una sección de install (TODO) y una de verify

Copiala, llená los huecos, validá (`shellcheck` + `bash -n`) y
colocá el resultado en `available/`.

## Cómo añadir un nuevo script de instalación

Tres casos, en orden de probabilidad:

### Caso 1: un script nuevo para una herramienta existente (el más común)

Estás añadiendo un segundo script de config de Pi, o querés partir
una instalación grande en dos más chicas. Sin cambios al Dockerfile,
sin cambios a `02-enabled/` — solo creá un archivo nuevo en
`available/` con el prefijo correcto:

```text
# Ejemplo: añadir un segundo archivo de settings para pi-coding
.devcontainer/install/available/30-ai-pi-extras.sh
```

`30-ai-` mantiene el orden intra-grupo (`30-ai-pi-coding.sh` →
`30-ai-pi-extras.sh`). Si querés que esté activo por defecto,
linkeá desde `02-enabled/`:

```bash
cd .devcontainer/install/02-enabled
ln -sfn ../available/30-ai-pi-extras.sh 30-ai-pi-extras.sh
```

Si solo opt-in, dejalo en `available/` y que los usuarios lo
habiliten con `task install:enable -- 30-ai-pi-extras`.

### Caso 2: una herramienta nueva con su propio runtime

Estás añadiendo Redis, kubectl, o cualquier herramienta con un
paso de instalación real (descarga de binario, apt install, etc.).
El script va en `available/` con el prefijo correcto y se linkea
desde `02-enabled/` para activación por defecto.

```text
# Ejemplo: añadir kubectl
.devcontainer/install/available/20-runtime-kubectl.sh
```

```bash
# desde la plantilla
cp .devcontainer/install/templates/install-script.sh \
   .devcontainer/install/available/20-runtime-kubectl.sh
# llená: descargar binario de kubectl, verificar, exit 0 si ya está presente
cd .devcontainer/install/02-enabled
ln -sfn ../available/20-runtime-kubectl.sh 20-runtime-kubectl.sh
```

La sección "State and volumes" en la cabecera de la plantilla te
explica cómo cablear el bind mount y el mapeo de volume-repair si
tu herramienta es dueña de un directorio con estado.

### Caso 3: una extensión personal / específica del sitio

Querés un script que corra en cada build pero solo para *tu*
clon. No lo agregues a `01-core/` (nivel proyecto) ni a `available/`
(catálogo). Usá `03-hooks/` en su lugar, que viene vacío y está
documentado en su propio README.

## Cómo verificar el árbol de instalación

Tres tareas te dicen el estado en vivo:

```bash
task install:list              # muestra 01-core, 02-enabled, hooks
task install:list --presets    # también muestra entradas .disabled en available/
task install:doctor            # verifica lib/, templates/, symlinks de enabled/
task install:volumes           # muestra el contrato de volúmenes (concern aparte)
```

El propio log del build muestra el orden de ejecución. Después de
`task container:up`, `grep "Running: " /tmp/<tu-build-log>.log`
imprime el orden real de los scripts que corrieron.
