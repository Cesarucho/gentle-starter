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
1. git clone repo  --> rename project-foo --> automated-steps --> prompt "create ..."
2. git clone repo  --> rename project-bar --> automated-steps --> prompt "design ..."
3. copy/paste repo --> rename project-baz --> automated-steps --> prompt "research ..."
```

## 📦 What's included?

The environment combines mandatory core tools with opt-in catalog tools and
integrations—not everything below is installed by default.

- **[OpenCode](https://opencode.ai/docs/)** as the default assisted-development
  interface.
- **[Pi Coding Agent](https://github.com/earendil-works/pi#quick-start)** as an
  opt-in alternative extensible harness (disabled by default).
- **[Gentle AI](https://github.com/Gentleman-Programming/gentle-ai)** for
  managed AI workflows alongside OpenCode, included in the mandatory core.
- **[Engram](https://github.com/Gentleman-Programming/engram#quick-start)** as local persistent memory inside the environment.
- **[Dev Container](https://code.visualstudio.com/docs/devcontainers/containers#_installation)** based on [Ubuntu 24.04](https://releases.ubuntu.com/noble/).
- **[Taskfile](https://taskfile.dev/installation/)** to centralize common commands.

You can activate catalog tools or add your own installers, with or without AI. See
[the install layout](docs/en/install-tree.md) and [cache boundaries](docs/en/container-foundation.md).
Run `task install:list` for the current catalog and activation state.

<details>
<summary>Supporting tools and optional extensions list: 👇🏼</summary>

### Environment and packages

| Tool | Purpose |
| --- | --- |
| [Node.js](https://nodejs.org/) | Run JavaScript programs and command-line development tools |
| [npm](https://www.npmjs.com/) | Install, publish, and manage JavaScript package dependencies |
| [pnpm](https://pnpm.io/) | Install and manage packages with a fast, workspace-aware workflow |
| [Go](https://go.dev/) | Compile and run Go applications and developer tools |
| [Java 25](https://sdkman.io/jdks#tem) | Run and build JVM applications with the optional toolchain |
| [SDKMAN](https://sdkman.io/) | Install and switch between Java SDK versions per environment |
| [Temurin](https://adoptium.net/temurin/) | Provide the default OpenJDK distribution for Java development |
| [PHP](https://www.php.net/) | Run PHP applications and command-line scripts |
| [Composer](https://getcomposer.org/) | Install and manage PHP application dependencies |

### Testing and debugging

| Tool | Purpose |
| --- | --- |
| [Bats](https://github.com/bats-core/bats-core) | Exercise shell scripts with readable Bash test cases |
| [PHPUnit](https://phpunit.de/) | Run unit and integration tests for PHP code |
| [Xdebug](https://xdebug.org/) | Inspect PHP execution with breakpoints and runtime diagnostics |
| [Vitest](https://vitest.dev/) | Run fast JavaScript and TypeScript unit tests |
| [Delve](https://github.com/go-delve/delve) | Debug Go programs with breakpoints and stack inspection |
| [Playwright](https://playwright.dev/) | Automate browser scenarios for end-to-end testing |
| [Chromium](https://www.chromium.org/) | Provide a browser runtime for automated test sessions |
| [@playwright/cli](https://www.npmjs.com/package/@playwright/cli) | Control browser sessions from agent workflows |

### Documentation, APIs and diagrams

| Tool | Purpose |
| --- | --- |
| [Context7](https://github.com/upstash/context7) | Retrieve current library documentation through MCP requests |
| [markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2) | Check Markdown style and formatting in documentation |
| [Glow](https://github.com/charmbracelet/glow) | Read and preview Markdown directly in a terminal |
| [Spectral CLI](https://www.npmjs.com/package/@stoplight/spectral-cli) | Lint API descriptions against reusable quality rules |
| [Redocly CLI](https://www.npmjs.com/package/@redocly/cli) | Validate, bundle, and preview OpenAPI descriptions |
| [AsyncAPI CLI](https://www.npmjs.com/package/@asyncapi/cli) | Validate and work with event-driven API descriptions |
| [Mermaid CLI](https://www.npmjs.com/package/@mermaid-js/mermaid-cli) | Render text-defined diagrams for documentation and reviews |
| [Archify](https://github.com/tt-a1i/archify) | Explore interactive diagrams for software architecture |
| [Graphviz](https://graphviz.org/) | Generate graphs from structured relationships and data |
| [PlantUML](https://plantuml.com/) | Create diagrams from concise text-based definitions |
| [C4-PlantUML](https://github.com/plantuml-stdlib/C4-PlantUML) | Model software architecture with C4 diagram conventions |
| [Graphify](https://pypi.org/project/graphifyy/) | Build and inspect knowledge graphs from connected concepts |
| [Graphify MCP](https://pypi.org/project/graphifyy/) | Expose graph operations to MCP-compatible clients |

### Infrastructure and security

| Tool | Purpose |
| --- | --- |
| [Docker Compose](https://docs.docker.com/compose/) | Build and run isolated application containers |
| [OpenSSH](https://www.openssh.com/) | Connect to hosts and provide secure remote shell access |
| [Ansible Core](https://docs.ansible.com/ansible-core/) | Automate repeatable configuration and deployment tasks |
| [kubectl](https://kubernetes.io/docs/reference/kubectl/) | Inspect and manage resources in Kubernetes clusters |
| [Terraform](https://developer.hashicorp.com/terraform) | Define and provision infrastructure from declarative configuration |
| [OpenTofu](https://opentofu.org/) | Provision infrastructure with an open-source declarative workflow |
| [Terragrunt](https://github.com/gruntwork-io/terragrunt) | Coordinate reusable infrastructure configurations and deployments |
| [Pulumi](https://github.com/pulumi/pulumi) | Provision cloud resources using general-purpose languages |
| [Gitleaks](https://github.com/gitleaks/gitleaks) | Scan repositories for accidentally committed secrets |

### Skills and agent extensions

| Tool | Purpose |
| --- | --- |
| [Skills CLI](https://github.com/vercel-labs/skills) | Install, update, and validate reusable agent skills |
| [Gentle Pi](https://www.npmjs.com/package/gentle-pi) | Extend Pi workflows with Gentle AI integrations |
| [Pi Subagents](https://www.npmjs.com/package/pi-subagents) | Run delegated Pi tasks through reusable subagent support |
| [Pi Intercom](https://www.npmjs.com/package/pi-intercom) | Exchange messages between Pi workflows and agents |
| [Pi Web Access](https://www.npmjs.com/package/pi-web-access) | Give Pi workflows controlled access to web resources |
| [Pi Lens](https://www.npmjs.com/package/pi-lens) | Provide real-time feedback while reviewing code changes |
| [RPIV Todo](https://www.npmjs.com/package/@juicesharp/rpiv-todo) | Track implementation tasks within Pi workflows |
| [RPIV Ask User Question](https://www.npmjs.com/package/@juicesharp/rpiv-ask-user-question) | Collect structured answers from users during Pi workflows |
| [RPIV BTW](https://www.npmjs.com/package/@juicesharp/rpiv-btw) | Handle side questions without interrupting the main task |
| [Gentle Engram](https://www.npmjs.com/package/gentle-engram) | Connect Pi workflows to persistent project memory |
| [Pi MCP Adapter](https://www.npmjs.com/package/pi-mcp-adapter) | Connect Pi to MCP servers and their tools |
| [Pi Terminal Theme](https://www.npmjs.com/package/pi-terminal-theme) | Customize terminal appearance for Pi sessions |

### Audio

| Tool | Purpose |
| --- | --- |
| [PulseAudio](https://www.freedesktop.org/wiki/Software/PulseAudio/) | Provide optional audio playback clients such as `paplay` |

Versioned skills provide a customizable base: external packages are tracked in
`skills-lock.json`; repository-authored skills live in `.agents/skills/` and
`.agents/local-skills.txt`. Host audio integration is separate from audio clients.

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

An IDE is optional and **does not replace** these host requirements.
`attach to running container` is the only supported method.

## 🚀 Quick start

### Fast path: start a new project from this base

1. On your PC:

    ```bash
    git clone https://github.com/Cesarucho/gentle-starter.git <my-project>
    cd <my-project>
    cp .env.example .env
    task project:init         # Remove the 'gentle-starter' identity and take ownership of the repository
    ```

    > `task project:init` is a recommended one-time option for creating a clean identity repository. After confirming
    > the `branch` and `origin` prompts, you'll have the foundation of the repository to start your own project
    > You can see the details with `task project:init -- --dry-run`.

### Build and enter the environment

Use the terminal workflow below. `Task` is the sole supported entry point in the life-cycle of a container
(build, create, run, stop, remove, restart, and more); an IDE may only attach after `task container:up`.

1. In your **host terminal**, from the project directory, run:

    ```bash
    task container:up         # it will build the image if needed

    # choose a "connect" method:
    task container:connect    # interactive terminal with bash
    task container:opencode   # directly to the ai-​agent application
    ```

2. If you chose `container:connect`, use any tool normally:

    ```bash
    git status
    engram --version
    gentle-ai --version
    opencode --version

    opencode auth login       # choose and authenticate a provider
    opencode -c               # open the ai-​​agent from the last session.
    ```

3. If you chose `container:opencode` or executed `opencode -c` inside of container, you can start with:

    choose and authenticate a provider

    ```bash
    >_ /connect
    ```

    and prompting, examples:

    ```text
    >_ Read @AGENTS.md.TEMPLATE and help me create AGENTS.md for my own proyect.

    >_ Use "add-tool" skill for add PostgreSQL-16 with a version-controlled
       `pg_hba.conf` and persistent data volume.
    ```

### Optional: attach container to IDE Code

1. Install IDE, for example [VS Code](https://code.visualstudio.com/download) and its
   **Dev Containers** extension on your host.
2. Run `task container:up` from the project directory **in your host terminal**, it can be
   the IDE terminal too.
3. In VS Code's Command Palette (`ctrl + shift + p`), run
   `Dev Containers: Attach to Running Container...` and choose this project's
   running container.
4. Use **File > Open Folder...** to open the actual workspace inside the
   container: `/home/ubuntu/<project-name>`.

**Do not use the IDE's Reopen in Container or Rebuild Container actions.**
These creation paths are unsupported because they bypass Task's host
preparation. From your host terminal, use `task container:restart` to recreate
the container from the existing image, or `task container:rebuild` to rebuild
the software and recreate it. Then [attach VS Code](https://code.visualstudio.com/docs/devcontainers/attach-container) again.

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

### 📦 Update development tools

```bash
task tools:update         # From inside container, update the repository's approved version policy
git diff                  # Review user intent and generated locks together
task container:rebuild    # From host, apply that policy to the development environment
task validate:full        # Inside container
```

Edit only `TOOL_*_VERSION` fields. `tools:update` alone resolves stable exact versions,
generates checksums, and atomically replaces the policy without updating installed tools.
Builds and installers are read-only; rebuild to apply, then commit after verification. See [ADR 0003](docs/en/adr/0003-unified-tool-policy-ownership.md).

If GitHub rate limits anonymous discovery, use an existing GitHub CLI
authentication explicitly:

```bash
TOOLS_UPDATE_USE_GH_AUTH=1 task tools:update
```

The opt-in is limited to `github.com`. A non-empty `GH_TOKEN` takes precedence;
otherwise the opt-in resolves `gh auth token` for `github.com`. GitHub REST
discovery responses are regenerated in the private local cache at
`${XDG_CACHE_HOME:-$HOME/.cache}/gentle-starter/tools-update/github-api/` and
use ETags to avoid unchanged requests.

### ⚙️ OpenCode and Pi configurations

- Keep your new preferences as the default setting.

    **Runtime files are the source of truth**. But during normal use, we often change our preferences;
    if we want to keep them as a base, we export them as part of our repository structure:

    ```bash
    # 1. Compare runtime configuration with the repository seed
    task config:diff

    # 2. Copy approved runtime files into the repository
    task config:export

    # 3. Review exactly what will be versioned
    git diff -- .devcontainer/opencode-config .devcontainer/pi-config
    ```

    `config:export` copies configuration in **container runtime → repository directory** direction:

    ```text
    /home/ubuntu/.config/opencode → .devcontainer/opencode-config
    /home/ubuntu/.pi              → .devcontainer/pi-config
    ```

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

- OpenCode profiles

    You can configure each **"sdd-*"** sub-agent with the model and effort to your liking
    (command: `/sdd-model`); these preferences are saved in runtime files
    `~/.config/opencode/opencode.json` and `~/.config/opencode/profiles/` which you
    can then export to default preferences `task config:export`:

    ```bash
    .devcontainer/opencode-config
    ├── opencode.json
    └── profiles/
        ├── openai-100usd-astral.json
        ├── openai-100usd-solar.json
        └── openai-20usd-pareto.json
    ```

    > Currently, opencode has the `openai-20usd-pareto` profile configured.

## 🛠️ Useful commands

### Diagnostics and validation

```bash
# Basic diagnostics
task doctor

# Host-safe repository validation (does not force specific skills)
task validate

# Strict validation, recommended inside the container
task validate:full

# Application tests: configure tasks.test.cmds in Taskfile.yml first
task test
```

### Install tools catalog management

```bash
# Show install scripts and the full dynamic catalog from .devcontainer/install/available/
task install:list

# Enable a new tool from .devcontainer/install/available/
task install:enable -- 2300-php-lang

# Disable a tool for future builds and postCreate runs
task install:disable -- 2300-php-lang

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
task container:connect          # open a shell; run `opencode` inside
task container:opencode         # direct TUI using `opencode --continue`
task container:opencode:server  # attach to a reused or task-owned OpenCode server
task container:pi               # connect to Pi using `pi --continue`
task container:engram           # connect to the Engram TUI
```

> `container:opencode:server` up the server mode, so you can connect from
> web-browser/application using `http://<IP>:<OPENCODE_PORT>/` address.
> `IP` can be: localhost, 127.0.0.1 or LAN/WLAN IP
>
> Also you can configure a optional credentials in `.env` file to set
> `OPENCODE_SERVER_USERNAME` and `OPENCODE_SERVER_PASSWORD`.

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

## 🗂️ Repository structure after project initialization

`task project:init` removes the Gentle Starter identity and leaves the
reusable devcontainer foundation in your project. It also creates the
`chore: initialize project` child commit, preserves the starter ancestry, and
configures the project branch and remotes you selected.

```text
.
├── .agents/                         Project-authored skills and local manifest
├── .devcontainer/                   Reusable development environment
│   ├── docs/                        Local devcontainer guides retained after initialization
│   ├── install/                     Foundation, core, enabled, hook, and catalog installers
│   ├── lifecycle/                   Internal post-create lifecycle helpers
│   ├── docker-compose.yml           Dev Container service and persistent binds
│   ├── README.md                    Devcontainer-specific documentation
│   ├── setup.sh                     Post-create configuration
│   └── tool-versions.conf           Centralized tool-version policy
├── .taskfiles/                      Task implementations and lifecycle tasks
├── .env.d/                          Local environment state, details below section
├── AGENTS.md.TEMPLATE               Starting point for your project AI instructions
├── .env.example                     Safe local environment-variable template
├── .gitignore                       Excludes local state and credentials
├── LICENSE                          Inherited Gentle Starter MIT attribution
├── skills-lock.json                 External skills lock file
├── Taskfile.yml                     Main Task entry point
└── openspec/                        Optional, preserved if it already exists
```

The starter `README.md`, `AGENTS.md`, `docs/`, `CHANGELOG.md`, root `odd/`
task artifacts, and optional `.github/` directory are removed. Create your own project README and AI
instructions from `AGENTS.md.TEMPLATE`.

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

Edit `.devcontainer/install/01-foundation/10-system.sh` to add packages installed with
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

Use the earlier [install catalog commands](#install-tools-catalog-management), or see
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
