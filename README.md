<div align="center">

<img width="80%" height="80%" alt="Gentle Starter Logo" src="./docs/assets/brand/gentle-starter-v2.png" />

<h1>🌱 Gentle Starter</h1>

<p><strong>Isolated and portable "ready-to-promtp" environment for Gentle-AI ecosystem</strong></p>

<p>
<a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
<img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey" alt="Platform">
</p>

</div>

---

## 🎯 ¿Qué hace?

Provee un entorno "ready-to-promtp" preconfigurado, multiplataforma, fiable, extensible y replicable para iniciar proyectos con AI de manera ordenada: entender el objetivo, aclarar requisitos, usar artefactos SDD/OpenSpec, aplicar skills, coordinar subagentes, implementar por fases (descubre > investiga > diseña > planea > implementa > verifica) iterando hasta obtener los resultados esperados.

El proyecto está pensado para ofrecer una estructura base limpia como punto de partida antes de lanzar cualquier prompt, logrando lo siguiente:

```shell
1. git clone repo  --> rename project-foo --> promtp "crea ..."
2. git clone repo  --> rename project-bar --> promtp "diseña ..."
3. copy/paste repo --> rename project-baz --> promtp "investiga ..."
```

## 📦 ¿Qué incluye?

- **[Pi Coding Agent](https://github.com/earendil-works/pi#quick-start)** como harness de desarrollo asistido.
- **[Gentle AI](https://github.com/Gentleman-Programming/gentle-pi#install)** para flujos de trabajo controlados con Pi.
- **[Engram](https://github.com/Gentleman-Programming/engram#quick-start)** como memoria local persistente dentro del entorno.
- **[Dev Container](https://code.visualstudio.com/docs/devcontainers/containers#_installation)** basado en [Ubuntu 24.04](https://releases.ubuntu.com/noble/).
- **[Docker Compose](https://docs.docker.com/compose/install/)** para construir y levantar el entorno.
- **[Taskfile](https://taskfile.dev/installation/)** para centralizar comandos frecuentes.
- **Skills versionadas**, un conjunto base y actualizable a tu gusto.
- **[Playwright](https://playwright.dev/docs/intro#installing-playwright)** para pruebas e2e (quizas debería quitarlo, no todos lo necesitan).
- Scripts separados para instalar y configurar dependencias en Ubuntu

## ✅ Requisitos

En tu PC necesitás:

- **[docker](https://docs.docker.com/get-started/get-docker/)**, **[git](https://git-scm.com/downloads)**, **[jq](https://jqlang.org/download/)**.
- **IDE** compatible con **[DevContainers](https://code.visualstudio.com/docs/devcontainers/containers#_installation)** ([VSCode](https://code.visualstudio.com/download), [Cursor](https://cursor.com/downloads), [IntelliJ](https://www.jetbrains.com/idea/download/)) con su respectiva extensión si aplica.

(Opcional) Si prefires usar tu terminal en lugar de un IDE (como yo), instala:

- **[Task](https://taskfile.dev/installation/)**.
- **[DevContainer-CLI](https://github.com/devcontainers/cli#installation)**.

## 🚀 Uso rápido

1. En tu PC

    ```bash
    git clone https://github.com/Cesarucho/gentle-starter.git <nombre-de-mi-proyecto>
    cd <nombre-de-mi-proyecto>
    #   `.env` debe de existir y funciona bien con todo por defecto
    cp .env.example .env
    #   (opcional) comprobación básica
    task doctor
    ```

2. Si usas **IDE** busca la opción `Dev Containers: Reopen in Container` (o similar). Si usas la **terminal** ejecuta:

    ```bash
    task devcontainer:up
    task devcontainer:connect
    ```

3. Dentro del contendor ya puedes usar cualquier herramienta con normalidad, si estas con un **IDE** busca la opción para abrir su terminal.

    ```bash
    git status
    engram tui
    pi update

    #   (opcional) comprobación básica interna
    task doctor

    #   También puedes instalar lo que te haga falta:
    sudo apt update
    sudo apt install {foo}
    ```
      > Nota.- Instalar herramientas al vuelo son recomendables para pruebas pero una vez validadas deben incluirse en `.devcontainers/scripts/...` como base.

4. Conecta con tu proveedor de AI:

    ```bash
    # Entra a la interfaz principal (a partir de ahora tu lugar favorito)
    pi

    # Elige proveedor, y repite si deseas registrar más de uno.
    /login

    # Si eliges uno DIFERENTE O ADICIONAL a OpenAI, promtea:
    >_ "Asigna la mejor configuración modelo/esfuerzo para cada agente de gentle-ai @.devcontainer/pi-config/gentle-ai/models.json con los modelos disponibles (pi --list-models) y de acuerdo a la guia: @docs/assets/ref/GUIA_MODELOS_v4.png"
    ```

    > Nota.- Ajustes personalizados con revisión manual: `/gentle:models`.
    

## 🛠️ Comandos útiles

```bash
# Diagnóstico
task doctor

# Devcontainer, solo útiles en tu PC (afuera del contenedor)
task devcontainer:build
task devcontainer:up
task devcontainer:rebuild
task devcontainer:connect

# Skills
task skill:sync
task skill:validate
```

## 🗂️ Estructura del repo

```text
.
├── .agents/                        Skills versionadas del proyecto
├── .atl/                           <-- no-versionable -->
├── CHANGELOG.md
├── .devcontainer
│   ├── devcontainer.json           Configuración del DevContainer
│   ├── devcontainer-lock.json
│   ├── docker-compose.yml          Servicio del DevContainer
│   ├── Dockerfile                  Imagen base del entorno de desarrollo         
│   ├── pi-config/                  Configuración base de pi y gentle-ai
│   ├── scripts/                    Scripts ejecutados durante el build de la imagen
│   └── setup.sh                    Script post-create del contenedor
├── docs
│   └── security.md
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
├── README.md
├── skills-lock.json                Archivo de bloqueo para restaurar skills
├── .taskfiles
│   ├── devcontainer.yml            Tareas para construir y operar el devcontainer
│   ├── doctor.yml                  Tareas de diagnóstico del host/devcontainer
│   ├── scripts                     Script de diagnóstico usado por `task doctor`
│   ├── skills.yml                  Tareas para gestionar skills del proyecto
│   └── ssh.yml
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
│   ├── engram.db
│   ├── engram.db-shm
│   └── engram.db-wal
├── .gitconfig                Configuración local de Git dentro del contenedor
│   ├── config
│   └── .git-credentials
└── .pi                       Estado y configuración local de Pi
    ├── agent/
    └── gentle-ai/
```

> Importante: no guardes tokens, credenciales ni bases locales en Git. El repo
> ignora `env/`, `.env`, `.pi/` y `.atl/` para evitar publicar estado local por
> accidente.

## ⚙️ Personalización básica

### 📥 Instalar paquetes del sistema

Editá `.devcontainer/scripts/01-install-apt.sh` para agregar paquetes instalados con `apt` durante la construcción de la imagen.

### 🌎 Actualizar zona horaria y locales

Editá los argumentos del Dockerfile `.devcontainer/Dockerfile`, por ejemplo:

```dockerfile
ARG LOCALE=es_MX.UTF-8
ARG TZ=America/Mexico_City
```

### 🧩 Agregar scripts de instalación

Agregá scripts numerados dentro de `.devcontainer/scripts/`.

Los scripts se ejecutan en orden durante el build de la imagen.

### 🧠 Gestionar skills

Las skills del proyecto viven en `.agents/skills/` y se controlan desde `skills-lock.json`

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

Ver [docs/security.md](./docs/security.md).

## 📝 Changelog

Ver [CHANGELOG.md](CHANGELOG.md).

## 📄 Licencia

MIT. Ver [LICENSE](LICENSE).
