<div align="center">

<img width="85%" height="85%" alt="Gentle Starter Logo" src="./docs/assets/brand/gentle-starter-v2.png" />

<h1>🌱 Gentle Starter</h1>

<p><strong>Isolated and portable "ready-to-prompt" environment for the Gentle AI ecosystem</strong></p>

<p>
<a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
<img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey" alt="Platform">
</p>

<p><strong>Documentation:</strong> <a href="./docs/en/README.md">English</a></p>

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
1. git clone repo  --> rename project-foo --> docker-steps --> prompt "create ..."
2. git clone repo  --> rename project-bar --> docker-steps --> prompt "design ..."
3. copy/paste repo --> rename project-baz --> docker-steps --> prompt "research ..."
```

## 📦 What's included?

- **[OpenCode](https://opencode.ai/docs/)** as the default assisted-development
  interface.
- **[Pi Coding Agent](https://github.com/earendil-works/pi#quick-start)** as an
  alternative extensible harness.
- **[Gentle AI](https://github.com/Gentleman-Programming/gentle-ai)** for
  controlled Pi workflows alongside OpenCode.
- **[Engram](https://github.com/Gentleman-Programming/engram#quick-start)** as local persistent memory inside the environment.
- **[Context7](https://github.com/upstash/context7)** integrated through MCP for current library documentation.
- **[Dev Container](https://code.visualstudio.com/docs/devcontainers/containers#_installation)** based on [Ubuntu 24.04](https://releases.ubuntu.com/noble/).
- **[Docker Compose](https://docs.docker.com/compose/install/)** to build and run the environment.
- **[Taskfile](https://taskfile.dev/installation/)** to centralize common commands.
- **Versioned skills**, a base set that you can update and customize.
- **[Playwright](https://playwright.dev/docs/intro#installing-playwright)** for optional e2e tests.
- **[Go](https://go.dev/doc/install)** and
  **[Java 25](https://sdkman.io/jdks#tem)** installers in the opt-in catalog;
  Java uses [SDKMAN](https://sdkman.io/install) and Temurin by default.
- **[pnpm](https://pnpm.io/installation)**, installed globally from the latest stable npm release.

<details>
<summary>Additional tools in the install catalog</summary>

- **Runtimes/testing:** Node.js, npm, Bats, PHP, Composer, PHPUnit, Xdebug,
  Vitest, Delve.
- **Docs/APIs/diagrams:** markdownlint-cli2, Glow, Spectral CLI, Redocly CLI,
  AsyncAPI CLI, Mermaid CLI, Graphviz, PlantUML, C4-PlantUML, Graphify,
  Graphify MCP.
- **Infrastructure/security:** OpenSSH server/client, Ansible Core, kubectl,
  Terraform, OpenTofu, Terragrunt, Pulumi, Gitleaks.
- **Agent extensions/browser:** Gentle Pi, Pi Subagents, Pi Intercom, Pi Web
  Access, Pi Lens, RPIV Todo, RPIV Ask User Question, RPIV BTW, Gentle Engram,
  Pi MCP Adapter, Pi Terminal Theme, Chromium, @playwright/cli.

Run `task install:list` for the current catalog and activation state.

</details>

## ✅ Requirements

On your PC you need:

- **[Git](https://git-scm.com/downloads)**
- **[Task](https://taskfile.dev/installation/)**
- **[Docker](https://docs.docker.com/get-started/get-docker/)**
- **[Dev Container CLI](https://github.com/devcontainers/cli#installation)**
- **[jq](https://jqlang.org/download/)**
- **[yq](https://github.com/mikefarah/yq/#install)** — Mike Farah yq v4 is
  recommended; volume discovery also supports Kislyuk yq.
- **[Python 3](https://www.python.org/downloads/)**

> Alternatively, use an IDE with Dev Container support, such as
> [VS Code](https://code.visualstudio.com/download),
> [Cursor](https://cursor.com/downloads), or
> [IntelliJ](https://www.jetbrains.com/idea/download/).

## 🚀 Quick start

### Fast path: start a new project from this base

1. On your PC:

    ```bash
    git clone https://github.com/Cesarucho/gentle-starter.git <my-project-name>
    cd <my-project-name>
    cp .env.example .env
    task project:init         # optional: configure the project and commit cleanup
    ```

    > `task project:init` is optional and one-time for a clean repository with Git identity configured. It prompts for a branch
    > and optional project `origin`, then configures canonical `upstream`; use exact `INIT` or `task project:init -- --dry-run`.

### Build and enter the environment

1. In your **terminal**, run:

    ```bash
    task container:up         # it will build the image if needed
    task container:connect
    ```

    > `container:up` derives `.env.d/` bind sources from Compose and creates them as the host user before Docker starts.
    > Dev Containers projects the host UID onto `ubuntu`, See [volume security](docs/en/install-volumes.md).

    If you use an **IDE**, first run `task container:up` to prepare host bind
    sources. Then use `Dev Containers: Reopen in Container` or its equivalent.

2. Inside the container, you can use any tool normally. If you are using an **IDE**, look for the option to open its terminal.

    ```bash
    git status
    engram --version
    gentle-ai --version
    opencode --version
    ```

3. Connect your AI provider and start OpenCode:

    ```bash
    opencode auth login       # choose and authenticate a provider
    opencode                  # open the default interface
    ```

    Example prompts:

    ```text
    >_ Read @AGENTS.md.TEMPLATE and help me create AGENTS.md by filling in the placeholders.

    >_ Read skill add-tool add PostgreSQL 16 with a version-controlled
       `pg_hba.conf` and persistent data volume.
    ```

## 🔄 Maintain your project

### 🌱 Update from Gentle Starter

Clones and forks share ancestry with Gentle Starter, so updates use ordinary Git.
Add the source repository once, then fetch and merge its main branch:

```bash
git remote add upstream https://github.com/Cesarucho/gentle-starter.git
git fetch upstream
git merge upstream/main
```

Resolve merge conflicts manually and commit the resolution normally. Existing
`origin` and branch upstream settings remain under project-owner control.

> GitHub repositories created with **Use this template** do not share commit
> ancestry with this repository, so they cannot use this merge workflow
> directly. Clone or fork instead. If a shallow clone lacks the merge base, run
> `git fetch --unshallow upstream` before merging.

### 📦 Update development tools

```bash
task deps:update          # From inside container, update the repository's approved version policy
task container:rebuild    # From host, apply that policy to the development environment
```

`deps:update` atomically replaces approved stable allowlist pins and reports
exclusions. Gentle AI stays advisory: review its version and digests together.
It never installs, rebuilds, or mutates live state. See [ADR 0002](docs/en/adr/0002-centralized-tool-version-policy.md).

### ⚙️ Save OpenCode and Pi configuration changes

Run these commands **inside the container** after changing OpenCode or Pi
settings:

```bash
# 1. Compare runtime configuration with the repository seed
task config:diff

# 2. Copy approved runtime files into the repository
task config:export

# 3. Review exactly what will be versioned
git diff -- .devcontainer/opencode-config .devcontainer/pi-config
```

`config:export` copies configuration in this direction:

```text
~/.config/opencode → .devcontainer/opencode-config
~/.pi              → .devcontainer/pi-config
```

The runtime files are the source of truth. Export:

- copies managed files byte for byte;
- never deletes seed files;
- refuses to run when the seed already has pending Git changes;
- excludes credentials, sessions, caches, logs, and generated dependencies;
- reports unknown paths without copying them.

To approve a new runtime path, add it to `managed` in
`.devcontainer/config-export.json`, then run the commands again.

For scripts that need the original comparison exit code, use:

```bash
task --exit-code config:diff
```

Exit code `0` means the managed files match; `1` means differences or candidates
were found; `2` means the comparison could not be completed safely.

See [Configuration](docs/en/configs.md) for the complete contract.

## 🛠️ Useful commands

### Diagnostics and validation

```bash
# Basic diagnostics
task doctor

# Host-safe repository validation (does not force specific skills)
task validate

# Strict validation, recommended inside the container
task validate:full

# Complete BATS test suite
task test
```

### Install catalog management

```bash
# Show install scripts and the full dynamic catalog from .devcontainer/install/available/
task install:list

# Enable a new tool from .devcontainer/install/available/
task install:enable -- 40-php-lang

# Disable a tool for future builds and postCreate runs
task install:disable -- 40-php-lang

# Verify install layout and symlink integrity
task install:doctor
```

### Language toolchain

```bash
# Available by default
pnpm --version

# Available after enabling their catalog installers
go version
java --version
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
task container:connect      # open a shell; run `opencode` inside
task container:opencode     # continue OpenCode using `opencode -c`
task container:pi           # connect to Pi using `pi --continue`
task container:engram       # connect to the Engram TUI
```

### Skills and quality

```bash
# Flexible project skills
task skill:sync

# Validate external lock entries and project-authored local skills
task skill:validate

# New-project initialization and identity cleanup (LICENSE is preserved)
task project:init           # configure branch/remotes, clean identity, and commit
task clean                  # clean identity but preserve Git history
task clean:identity         # explicit alias for task clean

# Script and Markdown quality checks
task quality:check
task quality:full
```

## 🗂️ Repository structure

```text
.
├── .agents/                         Versioned project skills and local manifest
├── .devcontainer/
│   ├── install/                     Core, enabled, hook, and catalog installers
│   ├── docker-compose.yml           Dev Container service and persistent binds
│   ├── setup.sh                     Post-create configuration
│   ├── setup-volumes.sh             Volume-to-installer runtime dispatch
│   └── tool-versions.conf           Centralized tool-version policy
├── .taskfiles/
│   ├── devcontainer.yml             Host container lifecycle tasks
│   └── scripts/                     Task implementation helpers
├── docs/en/                         Guides, security notes, and ADRs
├── AGENTS.md                        AI-facing repository context
├── AGENTS.md.TEMPLATE               Project identity template
├── README.md                        Main documentation
├── skills-lock.json                 External skills lock file
└── Taskfile.yml                     Main task entry point
```

## 💾 Local state and persistence

The `.env.example` file documents safe local variables for creating your own
`.env`:

```bash
cp .env.example .env
```

The `.env.d/` directory is intended to store local environment state and should not
be versioned. It is currently used to mount data such as:

```text
.env.d/                       Content <-- not versioned -->
├── .engram                   Local Engram database
│   ├── engram.db
│   ├── engram.db-shm
│   └── engram.db-wal
├── .gitconfig                Local Git configuration inside the container
│   ├── config
│   └── .git-credentials
├── .opencode                 Local OpenCode application state
│   └── share/
├── .gentle-ai                Local Gentle AI state
│   ├── backups/
│   ├── cache/
│   └── state.json
└── .pi                       Local Pi state and configuration
    ├── agent/
    └── gentle-ai/
```

> Important: do not commit tokens, credentials, or local databases to Git. The
> repository ignores `.env.d/`, `.env`, `.pi/`, and `.atl/` to avoid publishing
> local state by accident.

## ⚙️ Basic customization

### 📥 Install system packages

Edit `.devcontainer/install/01-core/10-system.sh` to add packages installed with
`apt` during the image build.

### 🌎 Update timezone and locales

Edit the Dockerfile arguments in `.devcontainer/Dockerfile`, for example:

```dockerfile
ARG LOCALE=es_MX.UTF-8
ARG TZ=America/Mexico_City
```

### 🧩 Add development tools

Ask OpenCode to use the project `add-tool` skill. Describe the tool, version,
whether it should be enabled by default, and any configuration or persistent
state it needs.

```text
Use the `add-tool` skill to add PostgreSQL 16.

Enable it by default, persist its data, add a version-controlled `pg_hba.conf`,
run the applicable tests, and do not commit or rebuild without my approval.
```

Use the earlier [install catalog commands](#install-catalog-management), or see
[Extending Gentle Starter](docs/en/extending.md) for the manual architecture.

### 🔌 Configure optional MCP servers

OpenCode MCP configuration is seeded from `.devcontainer/opencode-config/`.
Inspect active servers with:

```bash
opencode mcp list
```

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

Project skills live in `.agents/skills/`. External skills restored by the Skills
CLI are controlled from `skills-lock.json`; repository-authored skills are listed
one per line in `.agents/local-skills.txt`. `skill:prune` preserves the union and
`skill:validate` checks both sources without inventing external lock metadata.

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
git diff -- skills-lock.json .agents/local-skills.txt .agents/skills
```

## 🔐 Security

This starter uses Docker-in-Docker and elevated permissions for some development
flows. Do not publish `.env`, `.env.d/`, `.pi/`, or `.atl/`.

See [security.md](docs/en/security.md).

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md).

## 📄 License

MIT. See [LICENSE](LICENSE).
