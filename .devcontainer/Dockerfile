ARG IMAGE=ubuntu:24.04
FROM ${IMAGE} AS foundation

ARG LOCALE=es_MX.UTF-8
ARG TZ=America/Mexico_City
ARG UID_NAME=ubuntu

ENV DEBIAN_FRONTEND=noninteractive
ENV LOCALE=${LOCALE}
ENV TZ=${TZ}

WORKDIR /home/${UID_NAME}
COPY install/01-foundation/ ./.devcontainer-install/01-foundation/
COPY install/lib/common.sh install/lib/run-installers.sh ./.devcontainer-install/lib/

RUN LANG=C.UTF-8 LANGUAGE=C.UTF-8 LC_ALL=C.UTF-8 \
    chown -R "${UID_NAME}:${UID_NAME}" ./.devcontainer-install \
    && find ./.devcontainer-install -type f -name "*.sh" -exec chmod 0755 {} \; \
    && ./.devcontainer-install/lib/run-installers.sh ./.devcontainer-install/01-foundation

ENV LANG=${LOCALE}
ENV LANGUAGE=${LOCALE}
ENV LC_ALL=${LOCALE}

FROM foundation AS core-tools
ARG UID_NAME=ubuntu

# User globals must not shadow the policy-managed CLI. pnpm 11+ uses bin/;
# retain the home itself on PATH for older policy-selected pnpm releases.
ENV PNPM_HOME=/home/${UID_NAME}/.local/share/pnpm
ENV SHELL=/bin/bash
ENV PATH=${PATH}:${PNPM_HOME}/bin:${PNPM_HOME}

WORKDIR /home/${UID_NAME}
COPY tool-versions.conf ./.devcontainer-install/tool-versions.conf
COPY install/lib/tar-archive.sh ./.devcontainer-install/lib/
# Copy only core installers so optional catalog changes do not invalidate the core cache.
COPY install/available/1000-test-bats.sh install/available/2000-runtime-node.sh install/available/2010-runtime-pnpm.sh install/available/2020-node-markdownlint.sh install/available/2030-tool-devcontainer-cli.sh install/available/3000-ai-opencode.sh install/available/3010-ai-engram.sh install/available/3020-ai-gentle-ai.sh install/available/3050-ai-skills.sh ./.devcontainer-install/available/
COPY install/02-core-tools/ ./.devcontainer-install/02-core-tools/

RUN chown -R "${UID_NAME}:${UID_NAME}" ./.devcontainer-install \
    && find ./.devcontainer-install -type f -name "*.sh" -exec chmod 0755 {} \; \
    && ./.devcontainer-install/lib/run-installers.sh ./.devcontainer-install/02-core-tools

FROM core-tools AS devcontainer
ARG APP_NAME=project-name

COPY install/available/ ./.devcontainer-install/available/
COPY install/03-enabled/ ./.devcontainer-install/03-enabled/
COPY install/04-hooks/ ./.devcontainer-install/04-hooks/
COPY install/lib/ ./.devcontainer-install/lib/

RUN chown -R "${UID_NAME}:${UID_NAME}" ./.devcontainer-install \
    && find ./.devcontainer-install -type f -name "*.sh" -exec chmod 0755 {} \; \
    && ./.devcontainer-install/lib/run-installers.sh ./.devcontainer-install/03-enabled \
    && ./.devcontainer-install/lib/run-installers.sh ./.devcontainer-install/04-hooks

USER ${UID_NAME}
WORKDIR /home/${UID_NAME}/${APP_NAME}
CMD ["/bin/bash"]
