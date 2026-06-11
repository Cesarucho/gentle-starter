<div align="center">

<img width="85%" height="85%" alt="Gentle Starter Logo" src="./docs/assets/brand/gentle-starter-v2.png" />

<h1>🌱 Gentle Starter</h1>

<p><strong>Isolated and portable "ready-to-prompt" environment for the Gentle AI ecosystem</strong></p>

<p>
<a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
<img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey" alt="Platform">
</p>

<p><strong>Language:</strong> English · <a href="./docs/es/README.md">Español</a></p>

</div>

---

## 🎯 What does it do?

It provides a preconfigured, cross-platform, reliable, extensible, and
replicable "ready-to-prompt" environment for starting AI projects in an orderly
way: understand the goal, clarify requirements, use SDD/OpenSpec artifacts,
apply skills, coordinate subagents, implement in phases —discover, research,
design, plan, implement, and verify— and iterate until the expected results are
achieved.

The project is designed to provide a clean base structure before launching any
prompt, enabling workflows like these:

```shell
1. git clone repo  --> rename project-foo --> prompt "create ..."
2. git clone repo  --> rename project-bar --> prompt "design ..."
3. copy/paste repo --> rename project-baz --> prompt "research ..."
```

## 📦 What's included?

- **[Pi Coding Agent](https://github.com/earendil-works/pi#quick-start)** as the assisted-development harness.
- **[Gentle AI](https://github.com/Gentleman-Programming/gentle-pi#install)** for controlled Pi workflows.
- **[Engram](https://github.com/Gentleman-Programming/engram#quick-start)** as local persistent memory inside the environment.
- **[Context7](https://github.com/upstash/context7)** integrated through MCP for current library documentation.
- **[Dev Container](https://code.visualstudio.com/docs/devcontainers/containers#_installation)** based on [Ubuntu 24.04](https://releases.ubuntu.com/noble/).
- **[Docker Compose](https://docs.docker.com/compose/install/)** to build and run the environment.
- **[Taskfile](https://taskfile.dev/installation/)** to centralize common commands.
- **Versioned skills**, a base set that you can update and customize.
- **[Playwright](https://playwright.dev/docs/intro#installing-playwright)** for optional e2e tests.
- **[Go](https://go.dev/doc/install)**, installed from the latest stable release published by `go.dev`.
- **[Java 25](https://sdkman.io/jdks#tem)**, installed with [SDKMAN](https://sdkman.io/install) using the Temurin distribution by default.
- **[pnpm](https://pnpm.io/installation)**, installed globally from the latest stable npm release.
- Separate scripts to install and configure Ubuntu dependencies.

## ✅ Requirements

On your PC you need:

- **[Docker](https://docs.docker.com/get-started/get-docker/)**, **[Git](https://git-scm.com/downloads)**, and **[jq](https://jqlang.org/download/)**.
- An **IDE** compatible with **[Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers#_installation)** ([VS Code](https://code.visualstudio.com/download), [Cursor](https://cursor.com/downloads), [IntelliJ](https://www.jetbrains.com/idea/download/)) with its corresponding extension when needed.

Optional but recommended, use just the terminal instead of an IDE, install:

- **[Task](https://taskfile.dev/installation/)**.
- **[Dev Container CLI](https://github.com/devcontainers/cli#installation)**.

## 🚀 Quick start

1. On your PC:

    ```bash
    git clone https://github.com/Cesarucho/gentle-starter.git <my-project-name>
    cd <my-project-name>
    # `.env` must exist and works well with the default values.
    cp .env.example .env
    # Optional basic check.
    task validate
    ```

2. If you use an **IDE**, look for the `Dev Containers: Reopen in Container` option (or similar). If you use the **terminal**, run:

    ```bash
    task container:up
    task container:connect
    ```

3. Inside the container, you can use any tool normally. If you are using an **IDE**, look for the option to open its terminal.

    ```bash
    git status
    engram tui
    pi update

    # Optional internal check.
    task validate:full

    # You can also install anything else you need:
    sudo apt update
    sudo apt install {foo}
    ```

    > Note: installing tools on the fly is useful for experiments, but once
    > validated they should be added to `.devcontainer/install/...` as part of
    > the base environment.

4. Connect your AI provider:

    ```bash
    # Open the main interface (from now on, your favorite place).
    pi

    # Choose a provider and repeat if you want to register more than one.
    /login

    # ask to config the best model of each agent:
    >_ "Assign the best model/effort configuration for each gentle-ai agent in @.devcontainer/pi-config/gentle-ai/models.json and @.devcontainer/pi-config/agent/settings.json using the available models (pi --list-models) and following this guide: @docs/assets/ref/GUIA_MODELOS_v5.md"
    ```

    > Note: custom settings with manual review: `/gentle:models`.

## 🛠️ Useful commands

### Diagnostics and validation

```bash
# Basic diagnostics
task doctor

# Host-safe repository validation (does not force specific skills)
task validate

# Strict validation, recommended inside the container
task validate:full
```

### AI tooling

```bash
# Update Pi packages and re-pin selected packages with explicit versions
task ai:update

# Override the packages that should be re-pinned after update
task ai:update PINNED_PI_PACKAGES="pi-mcp-adapter another-package"

# Refresh Gentle AI model/effort config using the Markdown model guide
task ai:configure-models
```

Inside Pi, inspect MCP servers, including Context7:

```text
/mcp
```

### Language toolchain

```bash
# Available inside the devcontainer
go version
java --version
pnpm --version
```

### Container lifecycle

```bash
# Container commands, only useful on your PC (outside the container)
task container:build
task container:up
task container:restart      # remove and start the existing image
task container:rebuild      # remove, build, and start
```

### Container entrypoints

```bash
# These tasks auto-start the devcontainer if it is not running
task container:connect      # connect to the terminal
task container:pi           # connect to Pi using `pi --continue`
task container:engram       # connect to the Engram TUI
```

### Skills and quality

```bash
# Flexible project skills
task skill:sync

# Optional: only if you want to validate skills-lock.json against .agents/skills
task skill:validate

# Script quality checks
task quality:check
task quality:full
```

## 🗂️ Repository structure

```text
.
├── .agents/                        Versioned project skills
├── .atl/                           <-- not versioned -->
├── CHANGELOG.md
├── .devcontainer
│   ├── devcontainer.json           Dev Container configuration
│   ├── devcontainer-lock.json
│   ├── docker-compose.yml          Dev Container service
│   ├── Dockerfile                  Base image for the development environment
│   ├── install/                    Install layout (numbered groups, available catalog, helpers)
│   │   ├── 01-core/                Mandatory scripts (run in every build)
│   │   ├── 02-enabled/             Symlinks to active available/ scripts
│   │   ├── 03-hooks/               User extensions (gitignored)
│   │   ├── available/              Opt-in catalog (numbered 00-99)
│   │   ├── lib/                    Shared helpers (common.sh)
│   │   └── templates/              install-script.sh template
│   ├── pi-config/                  Base Pi, MCP, and Gentle AI configuration
│   └── setup.sh                    Container post-create script (volume-aware)
├── docs
│   ├── assets/
│   ├── en/README.md                Full English documentation
│   ├── es/README.md                Full Spanish documentation
│   ├── en/security.md              English security guide
│   └── es/security.md              Spanish security guide
├── .env                            <-- not versioned -->
├── env/                            Persistent local state, <-- not versioned -->
├── .env.example                    Example local variables for `.env`
├── .gitignore
├── LICENSE
|
├── openspec/                       Source of truth for your project and should
|                                   be versioned by you
|
├── .pi/                            <-- not versioned -->
├── README.md                       Main documentation (English)
├── skills-lock.json                Lock file for restoring skills
├── .taskfiles
│   ├── devcontainer.yml            Tasks to build and operate the Dev Container
│   ├── doctor.yml                  Host/devcontainer diagnostic tasks
│   ├── install.yml                 Tasks to manage the install/ layout
│   ├── scripts                     Diagnostic and install helper scripts
│   ├── skills.yml                  Tasks for managing project skills
│   └── ssh.yml
└── Taskfile.yml                    Main project task entry point
```

## 💾 Local state and persistence

The `.env.example` file documents safe local variables for creating your own
`.env`:

```bash
cp .env.example .env
```

The `env/` directory is intended to store local environment state and should not
be versioned. It is currently used to mount data such as:

```text
env/                          Content <-- not versioned -->
├── .engram                   Local Engram database
│   ├── engram.db
│   ├── engram.db-shm
│   └── engram.db-wal
├── .gitconfig                Local Git configuration inside the container
│   ├── config
│   └── .git-credentials
└── .pi                       Local Pi state and configuration
    ├── agent/
    └── gentle-ai/
```

> Important: do not commit tokens, credentials, or local databases to Git. The
> repository ignores `env/`, `.env`, `.pi/`, and `.atl/` to avoid publishing
> local state by accident.

## ⚙️ Basic customization

### 📥 Install system packages

Edit `.devcontainer/install/core/10-system.sh` to add packages installed with
`apt` during the image build.

### 🌎 Update timezone and locales

Edit the Dockerfile arguments in `.devcontainer/Dockerfile`, for example:

```dockerfile
ARG LOCALE=es_MX.UTF-8
ARG TZ=America/Mexico_City
```

### 🧩 Add installation scripts

The install layout is organized into three runtime groups (with a
visual-order prefix), the opt-in catalog, and shared infrastructure:

```text
.devcontainer/install/
├── 01-core/               Mandatory scripts (00-pre-apt, 10-system, 15-task,
│                          90-post-setup-users, 99-cleanup)
├── 02-enabled/            Symlinks to active available/ scripts
├── 03-hooks/              User extensions (gitignored)
├── available/             Opt-in catalog (numbered 00-99, .disabled suffix
│                          for opt-out defaults)
├── lib/                   Shared helpers (common.sh)
└── templates/             install-script.sh template for new scripts
```

The Docker build runs scripts in the order `01-core` → `02-enabled` →
`03-hooks` (the `for group in` loop in the Dockerfile). Within each
group, scripts are sorted by filename, so the numeric prefix inside
the filename (e.g. `20-runtime-…`, `30-ai-…`) controls the in-group
order. Scripts in `available/` are dormant until you link them into
`02-enabled/`.

To add a new opt-in tool:

```bash
# 1. Copy the template
cp .devcontainer/install/templates/install-script.sh \
   .devcontainer/install/available/40-cli-mycli.sh

# 2. Fill in the variables, idempotency check, install, and verify
#    sections. Source lib/common.sh for shared helpers (logging, arch
#    detection, devcontainer_run_as_root, devcontainer_has_cmd, etc.).

# 3. Validate locally
shellcheck .devcontainer/install/available/40-cli-mycli.sh
bash -n .devcontainer/install/available/40-cli-mycli.sh

# 4. Enable it (creates 02-enabled/40-cli-mycli.sh -> available/40-cli-mycli.sh)
task install:enable -- 40-cli-mycli

# 5. Rebuild and verify
task container:rebuild
```

Manage the install layout with these tasks:

```bash
task install:list                # Show active install scripts
task install:list --presets      # Also show disabled available/ entries
task install:enable -- NAME      # Enable a script by linking 02-enabled/ -> available/
task install:disable -- NAME     # Disable a script by removing its enabled/ link
task install:doctor              # Verify install/ layout integrity
```

A few rules for new scripts:

- Drop `-u` (nounset) only inside the subshell that sources SDKMAN.
  `lib/common.sh` runs under `set -euo pipefail`, but the Java carve-out
  uses `set -eo pipefail` inside the sudo heredoc to avoid
  `SDKMAN_CANDIDATES_API: unbound variable`.
- Use `devcontainer_run_as_root` instead of raw `sudo` so the script works
  in both build (root) and runtime (non-root) contexts.
- Use `devcontainer_has_cmd` for idempotency at the top of the script so
  re-runs are no-ops.
- Source files in `.devcontainer/install/` are mode 0755 to match the
  bind-mount and Dockerfile `chmod 0755` contract; the doctor task
  detects broken symlinks and missing helpers.

### 🔌 Configure optional MCP servers

Active Pi MCP configuration lives in:

```text
.devcontainer/pi-config/agent/mcp.json
```

Optional presets are versioned in:

```text
.devcontainer/pi-config/agent/mcp.presets.json
```

To enable a preset, copy its server entry into `mcp.json > mcpServers`, then
reload Pi with `/reload`. The GitHub preset requires
`GITHUB_PERSONAL_ACCESS_TOKEN` in `.env`; use a fine-grained token with the
minimum permissions required for your workflow.

### 🧠 Manage skills

Project skills live in `.agents/skills/` and are controlled from
`skills-lock.json`.

Useful commands:

```bash
task skill:add -- <package> --skill <skill-name>
task skill:install
task skill:update
task skill:validate
task skill:sync
```

After modifying skills, review and version the relevant changes:

```bash
git diff -- skills-lock.json .agents/skills
```

## 🔐 Security

This starter uses Docker-in-Docker and elevated permissions for some development
flows. Do not publish `.env`, `env/`, `.pi/`, or `.atl/`.

See [security.md](docs/en/security.md).

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md).

## 📄 License

MIT. See [LICENSE](LICENSE).