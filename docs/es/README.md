<div align="center">

<img width="85%" height="85%" alt="Logo de Gentle Starter" src="../assets/brand/gentle-starter-v2.png" />

<h1>🌱 Gentle Starter</h1>

<p><strong>Entorno aislado y portable "ready-to-prompt" para el ecosistema Gentle AI</strong></p>

<p>
<a href="../../LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="Licencia: MIT"></a>
<img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey" alt="Plataforma">
</p>

<p><strong>Idioma:</strong> <a href="../../README.md">Español</a> · English</p>

</div>

---

## 🎯 ¿Qué hace?

Provee un entorno "ready-to-prompt" preconfigurado, multiplataforma, fiable,
extensible y replicable para iniciar proyectos con AI de manera ordenada:
entender el objetivo, aclarar requisitos, usar artefactos SDD/OpenSpec, aplicar
skills, coordinar subagentes, implementar por fases —descubre, investiga,
diseña, planea, implementa y verifica— e iterar hasta obtener los resultados
esperados.

El proyecto está pensado para ofrecer una estructura base limpia como punto de
partida antes de lanzar cualquier prompt, logrando lo siguiente:

```shell
1. git clone repo  --> rename project-foo --> prompt "crea ..."
2. git clone repo  --> rename project-bar --> prompt "diseña ..."
3. copy/paste repo --> rename project-baz --> prompt "investiga ..."
```

## 📦 ¿Qué incluye?

- **[Pi Coding Agent](https://github.com/earendil-works/pi#quick-start)** como harness de desarrollo asistido.
- **[Gentle AI](https://github.com/Gentleman-Programming/gentle-pi#install)** para flujos de trabajo controlados con Pi.
- **[Engram](https://github.com/Gentleman-Programming/engram#quick-start)** como memoria local persistente dentro del entorno.
- **[Context7](https://github.com/upstash/context7)** integrado mediante MCP para documentación actualizada de librerías.
- **[Dev Container](https://code.visualstudio.com/docs/devcontainers/containers#_installation)** basado en [Ubuntu 24.04](https://releases.ubuntu.com/noble/).
- **[Docker Compose](https://docs.docker.com/compose/install/)** para construir y levantar el entorno.
- **[Taskfile](https://taskfile.dev/installation/)** para centralizar comandos frecuentes.
- **Skills versionadas**, un conjunto base y actualizable a tu gusto.
- **[Playwright](https://playwright.dev/docs/intro#installing-playwright)** para pruebas e2e opcionales.
- **[Go](https://go.dev/doc/install)**, instalado desde la última versión estable publicada por `go.dev`.
- **[Java 25](https://sdkman.io/jdks#tem)**, instalado con [SDKMAN](https://sdkman.io/install) usando la distribución Temurin por defecto.
- **[pnpm](https://pnpm.io/installation)**, instalado globalmente desde la última versión estable de npm.
- Scripts separados para instalar y configurar dependencias en Ubuntu.

## ✅ Requisitos

En tu PC necesitás:

- **[Docker](https://docs.docker.com/get-started/get-docker/)**, **[Git](https://git-scm.com/downloads)** y **[jq](https://jqlang.org/download/)**.
- Un **IDE** compatible con **[Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers#_installation)** ([VS Code](https://code.visualstudio.com/download), [Cursor](https://cursor.com/downloads), [IntelliJ](https://www.jetbrains.com/idea/download/)) con su respectiva extensión si aplica.

Opcional pero recomendado, usar solo la terminal en lugar de un IDE, instala:

- **[Task](https://taskfile.dev/installation/)**.
- **[Dev Container CLI](https://github.com/devcontainers/cli#installation)**.

## 🚀 Uso rápido

1. En tu PC:

    ```bash
    git clone https://github.com/Cesarucho/gentle-starter.git <nombre-de-mi-proyecto>
    cd <nombre-de-mi-proyecto>
    # `.env` debe existir y funciona bien con los valores por defecto.
    cp .env.example .env
    # Comprobación básica opcional.
    task validate
    ```

2. Si usás **IDE**, buscá la opción `Dev Containers: Reopen in Container` (o similar). Si usás la **terminal**, ejecutá:

    ```bash
    task container:up
    task container:connect
    ```

3. Dentro del contenedor ya podés usar cualquier herramienta con normalidad. Si estás con un **IDE**, buscá la opción para abrir su terminal.

    ```bash
    git status
    engram tui
    pi update

    # Comprobación interna opcional.
    task validate:full

    # También podés instalar lo que te haga falta:
    sudo apt update
    sudo apt install {foo}
    ```

    > Nota: instalar herramientas al vuelo es recomendable para pruebas, pero
    > una vez validadas deben incluirse en `.devcontainer/scripts/...` como base.

4. Conectá con tu proveedor de AI:

    ```bash
    # Entrá a la interfaz principal (a partir de ahora tu lugar favorito).
    pi

    # Elegí proveedor y repetí si querés registrar más de uno.
    /login

    # Ajuste los modelos que usa cada agente:
    >_ "Asigna la mejor configuración modelo/esfuerzo para cada agente de gentle-ai @.devcontainer/pi-config/gentle-ai/models.json con los modelos disponibles (pi --list-models) y de acuerdo a la guía: @docs/assets/ref/GUIA_MODELOS_v4.md"
    ```

    > Nota: ajustes personalizados con revisión manual: `/gentle:models`.

## 🛠️ Comandos útiles

### Diagnóstico y validación

```bash
# Diagnóstico básico
task doctor

# Validación host-safe del repo (no fuerza skills específicas)
task validate

# Validación estricta, recomendada dentro del contenedor
task validate:full
```

### Herramientas AI

```bash
# Actualiza paquetes de Pi y vuelve a fijar paquetes seleccionados con versión explícita
task ai:update

# Sobrescribe qué paquetes deben volver a fijarse después de actualizar
task ai:update PINNED_PI_PACKAGES="pi-mcp-adapter otro-paquete"

# Actualiza la configuración modelo/effort de Gentle AI usando la guía Markdown
task ai:configure-models
```

Dentro de Pi, inspeccioná servidores MCP, incluido Context7:

```text
/mcp
```

### Toolchain de lenguajes

```bash
# Disponible dentro del devcontainer
go version
java --version
pnpm --version
```

### Ciclo de vida del contenedor

```bash
# Container, solo útiles en tu PC (afuera del contenedor)
task container:build
task container:up
task container:restart      # elimina y levanta usando la imagen existente
task container:rebuild      # elimina, construye y levanta
```

### Entradas al contenedor

```bash
# Estas tareas levantan el devcontainer automáticamente si no está corriendo
task container:connect      # conecta a la terminal
task container:pi           # conecta a Pi usando `pi --continue`
task container:engram       # conecta a la TUI de Engram
```

### Skills y calidad

```bash
# Skills flexibles por proyecto
task skill:sync

# Opcional: solo si querés validar skills-lock.json contra .agents/skills
task skill:validate

# Calidad de scripts
task quality:check
task quality:full
```

## 🗂️ Estructura del repo

```text
.
├── .agents/                        Skills versionadas del proyecto
├── .atl/                           <-- no-versionable -->
├── CHANGELOG.md
├── .devcontainer
│   ├── devcontainer.json           Configuración del Dev Container
│   ├── devcontainer-lock.json
│   ├── docker-compose.yml          Servicio del Dev Container
│   ├── Dockerfile                  Imagen base del entorno de desarrollo
│   ├── pi-config/                  Configuración base de Pi, MCP y Gentle AI
│   ├── scripts/                    Scripts ejecutados durante el build de la imagen
│   └── setup.sh                    Script post-create del contenedor
├── docs
│   ├── assets/
│   ├── es/README.md
│   └── security.md
├── .env                            <-- no-versionable -->
├── env/                            Estado local persistente, <-- no-versionable -->
├── .env.example                    Ejemplo de variables locales para `.env`
├── .gitignore
├── LICENSE
|
├── openspec/                       Fuente de la verdad para tu proyecto y debe
|                                   ser versionado por tu cuenta
|
├── .pi/                            <-- no-versionable -->
├── README.md                       Main documentation (English)
├── skills-lock.json                Archivo de bloqueo para restaurar skills
├── .taskfiles
│   ├── devcontainer.yml            Tareas para construir y operar el Dev Container
│   ├── doctor.yml                  Tareas de diagnóstico del host/devcontainer
│   ├── scripts                     Script de diagnóstico usado por `task doctor`
│   ├── skills.yml                  Tareas para gestionar skills del proyecto
│   └── ssh.yml
└── Taskfile.yml                    Entrada principal de tareas del proyecto
```

## 💾 Estado local y persistencia

El archivo `.env.example` documenta variables locales seguras para crear tu
propio `.env`:

```bash
cp .env.example .env
```

El directorio `env/` está pensado para guardar estado local del entorno y no
debe versionarse. Actualmente se usa para montar datos como:

```text
env/                          Contenido <-- no-versionable -->
├── .engram                   Base local de Engram
│   ├── engram.db
│   ├── engram.db-shm
│   └── engram.db-wal
├── .gitconfig                Configuración local de Git dentro del contenedor
│   ├── config
│   └── .git-credentials
└── .pi                       Estado y configuración local de Pi
    ├── agent/
    └── gentle-ai/
```

> Importante: no guardes tokens, credenciales ni bases locales en Git. El repo
> ignora `env/`, `.env`, `.pi/` y `.atl/` para evitar publicar estado local por
> accidente.

## ⚙️ Personalización básica

### 📥 Instalar paquetes del sistema

Editá `.devcontainer/scripts/01-install-apt.sh` para agregar paquetes instalados
con `apt` durante la construcción de la imagen.

### 🌎 Actualizar zona horaria y locales

Editá los argumentos del Dockerfile `.devcontainer/Dockerfile`, por ejemplo:

```dockerfile
ARG LOCALE=es_MX.UTF-8
ARG TZ=America/Mexico_City
```

### 🧩 Agregar scripts de instalación

Agregá scripts numerados dentro de `.devcontainer/scripts/`.

Los scripts se ejecutan en orden durante el build de la imagen. La imagen base
usa este mecanismo para instalar el stack AI, Go, Java 25 y pnpm.

### 🧠 Gestionar skills

Las skills del proyecto viven en `.agents/skills/` y se controlan desde
`skills-lock.json`.

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

## 🔐 Seguridad

Este starter usa Docker-in-Docker y permisos elevados para algunos flujos de
desarrollo. No publiques `.env`, `env/`, `.pi/` ni `.atl/`.

Ver [security.md](security.md).

## 📝 Changelog

Ver [CHANGELOG.md](../../CHANGELOG.md).

## 📄 Licencia

MIT. Ver [LICENSE](../../LICENSE).
