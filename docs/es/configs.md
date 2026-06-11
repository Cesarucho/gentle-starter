# Siembra de configuraciones con `seed_config_tree`

`setup.sh` incluye un mecanismo paralelo para *archivos de
configuración*: un helper `seed_config_tree` que copia las
configuraciones base desde `.devcontainer/<name>-config/` a su
path de runtime. Es copy-on-first-run (idempotente, preserva las
personalizaciones del usuario a través de los rebuilds) y
escala automáticamente a `sudo` para targets fuera de `$HOME`.

Para la vista comprehensiva (cómo interactúan la siembra de
configs, los scripts de instalación y el volume repair, junto con
un ejemplo práctico), consultá
[`docs/es/extending.md`](./extending.md).

## La función

```bash
seed_config_tree(source_root, target_root)
```

- **Recorre el árbol fuente** bajo `source_root` (recursivamente, a
  cualquier profundidad) y copia cada archivo al path relativo
  equivalente bajo `target_root`.
- **Salta archivos que ya existen en el target** (idempotencia).
  Las personalizaciones del usuario se preservan a través de los
  rebuilds.
- **Escala automáticamente a `sudo`** para `mkdir -p` y `cp` cuando
  `target_root` está fuera de `$HOME` (por ejemplo
  `/etc/postgresql/16/main`, `/etc/redis`).
- **No-op** si `source_root` no existe (permite añadir el cableado
  antes de que el directorio exista).

## Detección de privilegios

```bash
local needs_sudo=false
if [ "${target_root:0:1}" = "/" ] \
    && [ "${target_root}" != "${HOME}" ] \
    && [ "${target_root#"$HOME"/}" = "${target_root}" ]; then
    needs_sudo=true
fi
```

Tres checks, en orden:

1. ¿Es el target un path absoluto? Si empieza con cualquier otra
   cosa (por ejemplo `~/.pi` o un path relativo), es un path de HOME
   y el usuario actual (ubuntu) puede escribir ahí.
2. ¿Es el target exactamente `$HOME`? También es un path de HOME.
3. ¿Empieza el target con `$HOME/`? Si es así, es un subpath de
   HOME; todavía sin sudo.

Si las tres son verdaderas, el target está genuinamente fuera de
`$HOME` y el helper escala. El caso de paths de sistema absolutos
(`/etc/...`, `/usr/local/...`, etc.) es el común.

## Los tres casos

### Caso 1: un archivo nuevo en `pi-config/`

Estás añadiendo una nueva config del agente de Pi, o partís una
existente en varios archivos. Sin cambios a `setup.sh`, sin cableado
nuevo — solo dropeá el archivo bajo `pi-config/` con el mismo path
relativo que debería tener en runtime. La primera vez que el
usuario rebuilda y el target no existe, el archivo se copia.
Después de eso, las personalizaciones del usuario quedan en su lugar.

```text
# Ejemplo: una nueva config del agente de Pi
.devcontainer/pi-config/agent/banner-presets.json
#   runtime: ~/.pi/agent/banner-presets.json
```

Commiteá el archivo. El próximo `task container:up` para un clon
fresco lo copia; para un clon existente, ya está (un build previo
o la herramienta lo habrá escrito).

### Caso 2: una herramienta nueva cuya config está en `$HOME`

Estás añadiendo kubectl, vscode, o cualquier herramienta cuya
config vive en el home del usuario (por ejemplo `~/.kube/config`,
`~/.config/Code/User/settings.json`). Tres pasos:

1. **Creá el source root** con el árbol de archivos que mirrorea
   la ubicación de la config de runtime de la herramienta:

   ```text
   # Ejemplo: config base de kubectl
   .devcontainer/kubectl-config/config
   #   runtime: ~/.kube/config
   ```

2. **Añadí una línea** a `setup_versioned_pi_config` en `setup.sh`:

   ```bash
   setup_versioned_pi_config() {
       seed_config_tree "${WORKSPACE_DIR}/.devcontainer/pi-config" "${HOME}/.pi"
       seed_config_tree "${WORKSPACE_DIR}/.devcontainer/kubectl-config" "${HOME}/.kube"
   }
   ```

3. **Documentá la elección** en la sección "Adding a new tool's
   baseline config" de `.devcontainer/README.md`, para que futuros
   contribuidores sepan que el cableado existe.

### Caso 3: una herramienta nueva cuya config está en `/etc` (o cualquier path de sistema)

Igual que el Caso 2, pero el target es un path de sistema donde
ubuntu no puede escribir. El helper detecta esto y escala a
`sudo` automáticamente — sin flag, sin cableado extra de tu parte.

```text
# Ejemplo: config base de postgresql
.devcontainer/postgres-config/16/main/pg_hba.conf
#   runtime: /etc/postgresql/16/main/pg_hba.conf
```

```bash
setup_versioned_pi_config() {
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/pi-config" "${HOME}/.pi"
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/postgres-config" "/etc/postgresql/16/main"
}
```

## Idempotencia: cómo se comporta a través de los rebuilds

| Escenario | Qué pasa |
|---|---|
| Primera ejecución, el directorio target está vacío | Cada archivo se copia. |
| Primera ejecución, el directorio target está vacío PERO la herramienta ya escribió algunos archivos en el target (por ejemplo `pi` escribió `mcp.json` después de un `/login`) | Los archivos escritos por la herramienta ya existen en el target; se quedan. Solo se copian los archivos que la herramienta aún no haya escrito. |
| Ejecuciones siguientes | Nada cambia (todos los targets ya existen). |
| El usuario borra un archivo del target y rebuilda | El archivo se vuelve a copiar desde la fuente (vuelve al baseline). |
| El usuario quiere "resetear a defaults" para un archivo | `rm <target>/<file>` y luego `task container:up` (o re-ejecutar `setup.sh` dentro del container). |

La regla de "solo copia si falta" es lo que hace que la convención
sea segura para personalizaciones del usuario: las ediciones del
usuario a un archivo del target sobreviven a cada rebuild hasta
que explícitamente borre el archivo.

## El patrón `*.local` para configs personales

El árbol `pi-config/` es compartido. Si querés añadir
configuraciones base que son personales a tu clon (no commiteadas),
usá un sufijo `<name>-config.local/`. El patrón `*-config.local/`
está en `.gitignore` así que el directorio queda untracked. Mismo
cableado que los Casos 2 y 3 arriba; el guard `if [ ! -d
"${source_root}" ]; then return 0` del helper maneja silenciosamente
un source root local ausente, así que la línea puede añadirse
incluso antes de que el directorio exista.

```bash
setup_versioned_pi_config() {
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/pi-config" "${HOME}/.pi"
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/postgres-config" "/etc/postgresql/16/main"
    # Personal: no commiteado, existe solo en este clon.
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/pi-config.local" "${HOME}/.pi" || true
}
```

El `|| true` es defensivo — el propio guard del helper lo hace
innecesario, pero sobrevive si alguien después refactoriza el
helper y olvida mantener el guard.

## Migración desde el enfoque legacy de symlinks

Builds anteriores de este proyecto usaban `ln -sfn` para symlinkar
la fuente versionada en la ubicación de runtime. Eso funcionaba
pero tenía dos puntos de dolor:

1. Herramientas que usan "atomic replace" para escribir sus
   archivos de config (notablemente Pi y algunos servidores MCP)
   rompen silenciosamente el symlink; `setup.sh` tenía que
   re-linkear defensivamente en cada postCreate.
2. Las personalizaciones del usuario eran incómodas: editar
   `~/.pi/agent/settings.json` significaba que el archivo era un
   symlink, así que el usuario tenía que `rm` el symlink primero,
   y el siguiente rebuild respaldaba el archivo personalizado a un
   `.devcontainer-backup.TIMESTAMP`.

El `seed_config_tree` actual resuelve ambos: los archivos reales
no se ven afectados por atomic-replace, y el usuario puede
editarlos libremente sin romper nada.

Para usuarios existentes, los symlinks siguen en su lugar (su
mtime es anterior al switch). El guard `if [ -e ]` de la nueva
función los deja correctamente. Para migrar, borrá los symlinks
y re-ejecutá `setup.sh`:

```bash
docker exec code-run rm -f \
    ~/.pi/agent/settings.json \
    ~/.pi/agent/mcp.json \
    ~/.pi/gentle-ai/banner.json \
    ~/.pi/gentle-ai/models.json \
    ~/.pi/gentle-ai/persona.json
docker exec code-run bash /home/ubuntu/code/.devcontainer/setup.sh
```

Después de eso, los cinco archivos son archivos regulares propiedad
de ubuntu y editables libremente.
