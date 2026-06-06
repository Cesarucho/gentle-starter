# Gentleman Starter

Esqueleto reproducible para iniciar proyectos con un entorno de desarrollo listo
para usar mediante Dev Containers, Task, Pi, Gentle AI, Engram y skills
versionadas.

La idea es que un desarrollador pueda clonar este repo, abrirlo en un
Dev Container y empezar a trabajar sin repetir configuraciones base en cada
proyecto nuevo.

## Qué incluye

- **Dev Container** basado en Ubuntu 24.04.
- **Docker Compose** para construir y levantar el entorno.
- **Taskfile** para centralizar comandos frecuentes.
- **Pi Coding Agent** como harness de desarrollo asistido.
- **Gentle AI** para flujos de trabajo controlados con Pi.
- **Engram** como memoria local persistente dentro del entorno.
- **Skills versionadas** en `.agents/skills/`.
- **Playwright** instalado desde la construcción de la imagen.
- Scripts separados para instalar y configurar dependencias del sistema.

## Requisitos

En la máquina host necesitás:

- Docker.
- VS Code, Cursor u otro editor compatible con Dev Containers.
- Extensión **Dev Containers** si usás VS Code o Cursor.
- Git.

Opcional, si querés ejecutar tareas del devcontainer desde el host:

- [Task](https://taskfile.dev/).
- [Dev Container CLI](https://github.com/devcontainers/cli).

## Uso rápido

```bash
# En el host
git clone <repo-url> gentle-starter
cd gentle-starter
cp .env.example .env
task doctor

# Conexión al contenedor con `devcontainer-cli` y `task`:
#   Si es primera vez
task devcontainer:build
#   Entra por bash al contenedor
task devcontainer:up
task devcontainer:connect

# Conexión alternativa desde el editor: `Dev Containers: Reopen in Container`

# Dentro del contendor:
#   Si es primera vez, solo para comprobar
task doctor   
#   Usa `Pi` o cualquier otra herramienta con normalidad
pi
```

## Comandos útiles

```bash
# Diagnóstico
task doctor                 # autodetecta host/devcontainer
task doctor:host            # ejecutar desde el host
task doctor:container       # ejecutar dentro del devcontainer

# Devcontainer
task devcontainer:build     # útil solo en host
task devcontainer:up        # útil solo en host
task devcontainer:rebuild   # útil solo en host
task devcontainer:connect

# Skills
task skill:sync
task skill:validate
```

## Estructura del repo

```text
.devcontainer/
  Dockerfile              Imagen base del entorno de desarrollo
  docker-compose.yml      Servicio del devcontainer
  devcontainer.json       Configuración del Dev Container
  scripts/                Scripts ejecutados durante el build de la imagen
  setup.sh                Script post-create del contenedor

.taskfiles/
  doctor.yml              Tareas de diagnóstico del host/devcontainer
  devcontainer.yml        Tareas para construir y operar el devcontainer
  skills.yml              Tareas para gestionar skills del proyecto
  scripts/doctor.sh       Script de diagnóstico usado por `task doctor`

.agents/skills/           Skills versionadas del proyecto
skills-lock.json          Archivo de bloqueo para restaurar skills
Taskfile.yml              Entrada principal de tareas del proyecto
.env.example              Ejemplo de variables locales para `.env`
env/                      Estado local persistente, no versionado
```

## Estado local y persistencia

El archivo `.env.example` documenta variables locales seguras para crear tu
propio `.env`:

```bash
cp .env.example .env
```

El directorio `env/` está pensado para guardar estado local del entorno y no
debe versionarse.

Actualmente se usa para montar datos como:

```text
env/.pi/          Estado y configuración local de Pi
env/.engram/      Base local de Engram
env/.gitconfig/   Configuración local de Git dentro del contenedor
```

> Importante: no guardes tokens, credenciales ni bases locales en Git. El repo
> ignora `env/`, `.env`, `.pi/` y `.atl/` para evitar publicar estado local por
> accidente.

## Personalización básica

### Cambiar nombres del Dev Container

La configuración usa un servicio genérico llamado `dev` y mantiene nombres de
imagen/contenedor asociados al starter:

```text
.devcontainer/devcontainer.json
.devcontainer/docker-compose.yml
```

Si querés personalizarlos para tu proyecto, editá esos dos archivos y cambiá:

- `name` en `devcontainer.json`;
- `image` en `docker-compose.yml`;
- `container_name` en `docker-compose.yml`.

### Instalar paquetes del sistema

Editá:

```text
.devcontainer/scripts/01-install-apt.sh
```

Usalo para agregar paquetes instalados con `apt` durante la construcción de la
imagen.

### Cambiar Node, zona horaria o locale

Editá los argumentos del Dockerfile:

```text
.devcontainer/Dockerfile
```

Por ejemplo:

```dockerfile
ARG NODE_MAJOR=26
ARG LOCALE=es_MX.UTF-8
ARG TZ=America/Mexico_City
```

### Agregar scripts de instalación

Agregá scripts numerados dentro de:

```text
.devcontainer/scripts/
```

Los scripts se ejecutan en orden durante el build de la imagen.

### Gestionar skills

Las skills del proyecto viven en:

```text
.agents/skills/
```

Y se controlan desde:

```text
skills-lock.json
```

Comandos útiles:

```bash
task skill:add -- <package> --skill <skill-name>
task skill:install
task skill:update
task skill:validate
task skill:sync
```

Después de modificar skills, revisá y versioná los cambios relevantes:

```bash
git diff -- skills-lock.json .agents/skills
```

## Seguridad

Este starter usa Docker-in-Docker y permisos elevados para algunos flujos de
desarrollo. No publiques `.env`, `env/`, `.pi/` ni `.atl/`.

Ver [docs/security.md](./docs/security.md).

## Changelog

Ver [CHANGELOG.md](CHANGELOG.md).

## Licencia

MIT. Ver [LICENSE](LICENSE).
