# Gentle Starter

Provee un entorno "ready-to-promtp" preconfigurado, multiplataforma, fiable, extensible y replicable para iniciar proyectos con AI aprovechando, pero sin limitarse, al ecosistema de pi, gentle-ai y engram. Más adelante se incluiran otros agentes y herramientas.

El objetivo es que el desarrollador use este repositorio como estructura base para cualquier proyecto que desee crear, agnóstico al stack tecnológico que desee implementar, por eso no hay nada referente a un lenguaje, front, back, infra, etc.

## Qué incluye

- **Dev Container** basado en Ubuntu 24.04.
- **Docker Compose** para construir y levantar el entorno.
- **Taskfile** para centralizar comandos frecuentes.
- **Pi Coding Agent** como harness de desarrollo asistido.
- **Gentle AI** para flujos de trabajo controlados con Pi.
- **Engram** como memoria local persistente dentro del entorno.
- **Skills versionadas** en `.agents/skills/`.
- **Playwright** para pruebas e2e (quizas debería quitarlo, no todos lo necesitan).
- Scripts separados para instalar y configurar dependencias en Ubuntu

## Requisitos

En tu PC necesitás:

- **Docker**.
- **IDE** compatible con **DevContainers** (VSCode, Cursor, IntelliJ).
- Extensión **DevContainers** si aplica para tu IDE.
- **Git**.

Opcional, si prefires tu terminal en lugar de un IDE (como yo), instala:

- [**Task**](https://taskfile.dev/).
- [**DevContainer-CLI**](https://github.com/devcontainers/cli).

## Uso rápido

```bash
# En tu PC
git clone -b dev https://github.com/Cesarucho/gentle-starter.git
cd gentle-starter
#   `.env` debe de existir y funciona bien con todo por defecto
cp .env.example .env

# Si usas terminal (`devcontainer-cli` y `task`) ejecuta:
#   Si es primera vez
task devcontainer:build
#   Entra por bash al contenedor
task devcontainer:up
task devcontainer:connect

# Si usas IDE busca opción `Dev Containers: Reopen in Container` o similar.

# Dentro del contendor ya puedes usar `pi`, `engram`, `git` o cualquier otra herramienta con normalidad:
pi
engram tui
git status

# También puedes instalar lo que te haga falta, como la base es ubuntu:
sudo apt update
sudo apt install {foo}
# Nota.- se recomienda instalar herramientas al vuelo solo para probar pero luego deben
#        versionarse `.devcontainers/scripts` para incluirlas como base según tus necesidades
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

La configuración crea una imagen `gentle-starter-img` y un contenedor `gentle-starter-run` defindos
en `.devcontainer/docker-compose.yml`.

Si tienes más de un proyecto, es necesario personalizar los nombres para evitar solapamientos.

```yaml
# .devcontainer/docker-compose.yml:
...
services:
  dev:
    image: {change-this}-img:0.1
    container_name: {change-this}-run
    ...

# .devcontainer/devcontainer.json:
{
    "name": "{change-this}",
    ...
```

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
