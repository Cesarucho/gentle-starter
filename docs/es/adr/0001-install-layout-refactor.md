# ADR 0001: Refactor del layout de instalación

**Estado:** Aceptado, 2026-06-11
**Reemplaza:** el layout legacy de `.devcontainer/scripts/` y el
patrón de siembra de configs basado en `ln -sfn` en `setup.sh`

## Contexto

Antes de este refactor, el devcontainer tenía tres problemas que
se acumulaban con el tiempo:

1. **Sin mecanismo de opt-in.** Cada script en
   `.devcontainer/scripts/` corría en cada build. No había forma
   de activar o desactivar un script sin editar el Dockerfile o
   mover archivos.
2. **Sin helpers compartidos.** Cada script reimplementaba los
   mismos idioms (`dpkg --print-architecture`, `curl -fsSL`,
   alternancia `sudo`/root, `set -euo pipefail`).
3. **La config de Pi era un symlink que se rompía.**
   Varias herramientas (notablemente Pi y algunos servidores
   MCP) escriben sus archivos de config con semántica de
   "atomic replace", lo que silenciosamente convierte el symlink
   en `~/.pi/agent/mcp.json` en un archivo regular al primer
   write. `setup.sh` tenía un baile defensivo de re-link
   (`setup_versioned_pi_config` se llamaba dos veces en el
   pipeline) para tapar esto.

El proyecto tampoco tenía forma de añadir configs base para
herramientas nuevas (Redis, kubectl, vscode, etc.) sin editar
`setup.sh` para agregar un par hardcodeado `(source, target)`
por archivo.

## Decisión

El refactor introdujo los siguientes cambios coordinados, todos
aterrizando en los commits `f5e9679` a `c11d975` más follow-ups.

### 1. Layout de tres grupos de runtime bajo `install/`

```text
.devcontainer/install/
├── 01-core/                # obligatorio, corre en cada build
├── 02-enabled/             # symlinks a scripts activos de available/
├── 03-hooks/               # extensiones del usuario (intencionalmente no gitignored)
├── available/              # catálogo opt-in (numerados 00-99)
├── lib/                    # helpers compartidos (common.sh)
└── templates/              # plantilla install-script.sh
```

El Dockerfile itera `01-core/`, `02-enabled/`, `03-hooks/` en
ese orden (`for group in 01-core 02-enabled 03-hooks`). Dentro
de cada grupo, los scripts se ordenan por nombre de archivo; el
prefijo numérico de cada script controla el orden intra-grupo.
Los prefijos de los directorios (`01-`, `02-`, `03-`) son una
pista visual, no load-bearing para el orden.

El `find` usa `-L` para seguir symlinks, que es la forma en que
`02-enabled/` (todos symlinks) hace que los cuerpos de los
scripts realmente se ejecuten.

### 2. `lib/common.sh` con guard de re-source

13 helpers: detección de fase, normalización de arquitectura,
chequeo de comandos, descarga + integridad, escalación de
privilegios, install, logging. El guard de re-source al inicio
hace que el archivo sea seguro de sourcear desde cualquier script
múltiples veces. Ver el comentario de cabecera en `lib/common.sh`
para el contrato completo.

### 3. `templates/install-script.sh`

El punto de partida canónico para scripts de instalación nuevos.
Shebang, `set -euo pipefail` (con un carve-out documentado para
subshells de SDKMAN), `: "${VAR:=default}"` para variables, guard
de idempotencia vía `devcontainer_has_cmd`, secciones de install
y verify. Copiar, llenar, validar, colocar en `available/`.

### 4. `seed_config_tree` para siembra de configs (copy, no symlinks)

Reemplaza la siembra legacy basada en symlinks. Recorre el
árbol fuente, copia cada archivo al path relativo equivalente
bajo el target, pero solo si el target NO existe ya (idempotente,
preserva personalizaciones del usuario). Cuando el target está
fuera de `$HOME` (por ejemplo `/etc/postgresql/16/main`,
`/etc/redis`), el helper escala a `sudo` para `cp` y `mkdir`
automáticamente.

`seed_config_tree` es el único bloque de construcción para la
siembra de configs. Añadir la config base de una herramienta
nueva = crear `<name>-config/` + agregar una llamada a
`seed_config_tree` en `setup_versioned_pi_config` en `setup.sh`.
El árbol fuente ES el manifiesto.

### 5. `setup-volumes.sh` extraído de `setup.sh`

El contrato de volume-repair (parsea `docker-compose.yml` para
bind mounts, mapea target paths a scripts de instalación
propietarios, re-corre esos scripts en runtime) vivía en
`setup.sh` y era opaco. Ahora vive en su propio archivo
(`.devcontainer/setup-volumes.sh`) que `setup.sh` sourcea. La
cabecera de `setup-volumes.sh` documenta el contrato de tres
piezas (volumen en compose + case en
`compose_target_to_install_scripts` + script de instalación) y el
paso a paso para añadir un volumen con estado nuevo.

### 6. Defaults de versiones de librerías en los scripts, no en el Dockerfile

Los ARGs `ENGRAM_VERSION`, `NODE_MAJOR` y `PLAYWRIGHT_VERSION`
del Dockerfile perdieron sus defaults. El default canónico vive
ahora en el script de instalación que consume el valor
(30-ai-engram.sh, 20-runtime-node.sh, etc.). Los ARGs siguen
existiendo para que los usuarios puedan overridear vía
`docker build --build-arg VAR=...`, y la propagación del `ENV`
en runtime sigue funcionando. Los ARGs de locale (`LOCALE`) y
timezone (`TZ`) mantienen sus defaults porque setean los `ENV`
`LANG`/`LC_ALL`/`TZ` en runtime, a los que un script no puede
llegar.

### 7. `devuser` removido

El proyecto usa `ubuntu` como única identidad del devcontainer.
Los ARGs `HOST_UID`/`HOST_GID` en el Dockerfile y el bloque de
creación de `devuser` en `90-post-setup-users.sh` fueron
removidos.

### 8. `PLATFORM_ARCH` muerto removido

El ARG `PLATFORM_ARCH` y su matching `ENV` no tenían ningún
consumidor en el proyecto. Removidos.

### 9. `install/03-hooks/` intencionalmente NO en .gitignore

Scripts dropeados en `03-hooks/` aparecen en `git status`. El
usuario puede decidir qué hacer (committearlos como opt-in a
nivel proyecto moviéndolos a `available/`, o dejarlos untracked
como personales). Razón: herramientas como `git status --ignored`
son suficientes para el usuario que quiere ignorar el contenido
del directorio.

### 10. Capa de descubribilidad

Cuatro superficies atrapan al contribuidor en diferentes
momentos:

- `install/templates/install-script.sh` — una sección "State and
  volumes" en la cabecera.
- `.devcontainer/docker-compose.yml` — un comment arriba de
  `volumes:` que apunta a `setup-volumes.sh` y a
  `task install:volumes`.
- `task install:volumes` — imprime el contrato vivo
  bind-mount → script propietario.
- `docs/install-volumes.md` — la referencia en profundidad.

El mismo patrón de descubribilidad se aplicó después al sistema
de siembra de configs (`docs/configs.md`, el helper
`seed_config_tree`, etc.).

### 11. Documentación bajo `docs/en/` (con mirror en `docs/es/`)

`docs/en/` es canónico; `docs/es/` es la traducción al español.
Archivos: `README.md` (índice), `extending.md` (la guía
comprensiva), `install-tree.md`, `install-volumes.md`,
`configs.md`. Más `AGENTS.md` en el root del repo para contexto
dirigido a IAs.

## Consecuencias

### Positivas

- **Extensibilidad.** Añadir una herramienta nueva (install +
  config + volume) es ahora cuestión de tres archivos en lugares
  conocidos más una o dos llamadas a `seed_config_tree`. No más
  editar `setup.sh` a mano con pares hardcodeados.
- **Idempotencia.** Los tres sistemas son idempotentes: los
  scripts de instalación usan guards `devcontainer_has_cmd`, el
  seeder de configs usa skips `if [ -e ]`, el volume repair
  re-corre scripts con `DEVCONTAINER_PHASE=runtime` y deja que
  el guard de idempotencia de cada script decida. Un rebuild
  es no-op para cualquier estado que ya esté correcto.
- **Descubribilidad.** Cuatro superficies (cabecera de la
  plantilla, comment de compose, `task install:volumes`, doc
  en profundidad) atrapan al contribuidor en diferentes
  momentos del journey. `AGENTS.md` en el root le da a
  cualquier coding agent el contexto de alto nivel en una sola
  lectura.
- **No más baile de symlinks.** `seed_config_tree` crea
  archivos reales. El atomic-replace de las tools ya no rompe
  nada. El pipeline puede llamar `setup_versioned_pi_config`
  una vez, no dos.

### Trade-offs aceptados

- **Archivos fuente en `install/` son mode 0755.** El workspace
  está bind-mounteado al devcontainer, así que el `chmod 0755`
  del Dockerfile sobre el target del COPY también afecta al
  árbol fuente. Esto es por diseño, no un bug, pero significa
  que cada `git status` después de un rebuild muestra un
  cambio de mode en cada script de install.
- **Sin auto-update de personalizaciones del usuario.** Si el
  proyecto actualiza `pi-config/agent/mcp.json` upstream, los
  usuarios que hayan editado su `~/.pi/agent/mcp.json` no
  reciben el update (el seeder respeta el archivo existente).
  Esto es deliberado: el proyecto es un starter, no un SaaS;
  los usuarios forkean y customizan. Se propuso un
  `task pi:diff-config` para ayudar con esto pero el usuario
  declinó.
- **Bind mounts, no named volumes.** El proyecto usa bind mounts
  del host para `~/.pi`, `~/.engram`, etc. para que el usuario
  tenga acceso físico directo (`cat env/.pi/agent/mcp.json`,
  `cp -r env/ backup/`). El trade-off: el estado vive en el
  working tree (per-clon, no per-máquina) y está en
  `.gitignore`. Se diseñó y testeó un par
  `task env:backup` / `task env:restore` pero el usuario
  eligió diferirlo.
- **Tres archivos en `install/03-hooks/` en `git status`.**
  Scripts dropeados ahí no se auto-ignoran. Trade-off aceptado
  por visibilidad explícita.

### Diferido (no parte de esta decisión)

- `task env:backup` y `task env:restore` — diseñados, testeados,
  revertidos a pedido del usuario. El historial de la
  conversación tiene el diseño completo.
- `task pi:diff-config` — propuesto, declinado.
- Traducción al español de `docs/en/install-volumes.md` y
  `.devcontainer/README.md` — decidido en contra.
- Adopción de OpenSpec (`openspec/changes/...`) — el usuario
  eligió explícitamente mantener `openspec/` untracked por
  ahora.

## Verificación

El refactor se validó en múltiples puntos:

- `task install:up` rebuilda la imagen y corre el hook
  postCreate. Las 13 `Running:` lines de build-phase corren en
  el orden correcto; 3 `Volume repair:` lines corren en el
  log de postCreate.
- Los 14 tools presentes en el container después del rebuild:
  `curl`, `jq`, `git`, `task`, `node`, `npm`, `pnpm`, `go`,
  `gofmt`, `java`, `javac`, `pi`, `engram`, `skills`.
- `task validate` y `task validate:full` ambos exit 0 con 0
  errors, 0 warnings.
- `task install:volumes` imprime el contrato vivo.
- `task install:list` imprime los scripts activos y los symlinks
  habilitados.
- `task install:doctor` reporta `ok: install layout`.

La baseline pre-refactor (la Fase 0 original del spec) tenía el
mismo set de 14 tools. El refactor preserva el comportamiento
para el build existente; cambia el layout, la superficie de
extensibilidad y el cableado de postCreate, pero no el set de
tools.
