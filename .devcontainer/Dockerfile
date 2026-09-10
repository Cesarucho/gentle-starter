ARG IMAGE=ubuntu:24.04
FROM ${IMAGE} AS foundation

ARG LOCALE=es_MX.UTF-8
ARG TZ=America/Mexico_City
ARG UID_NAME=ubuntu

ENV DEBIAN_FRONTEND=noninteractive
ENV LOCALE=${LOCALE}
ENV TZ=${TZ}

WORKDIR /home/${UID_NAME}
COPY install/01-core/ ./.devcontainer-install/01-core/
COPY install/lib/common.sh install/lib/run-installers.sh ./.devcontainer-install/lib/

RUN LANG=C.UTF-8 LANGUAGE=C.UTF-8 LC_ALL=C.UTF-8 \
    chown -R "${UID_NAME}:${UID_NAME}" ./.devcontainer-install \
    && find ./.devcontainer-install -type f -name "*.sh" -exec chmod 0755 {} \; \
    && ./.devcontainer-install/lib/run-installers.sh ./.devcontainer-install/01-core

ENV LANG=${LOCALE}
ENV LANGUAGE=${LOCALE}
ENV LC_ALL=${LOCALE}

FROM ${IMAGE} AS devcontainer-version-contract

# User-editable tool intent and generated exact resolutions and checksums are
# owned by tool-versions.conf. Installers consume that policy read-only; this
# Dockerfile only carries explicit build-argument overrides and their runtime
# environment.
# Keep this contract block in sync with devcontainer; focused tests enforce it.
ARG ENGRAM_VERSION=
ARG NODE_MAJOR=
ARG PLAYWRIGHT_VERSION=

ENV ENGRAM_VERSION=${ENGRAM_VERSION}
ENV NODE_MAJOR=${NODE_MAJOR}
ENV PLAYWRIGHT_VERSION=${PLAYWRIGHT_VERSION}

# Keep a cheap target that tests can build and inspect to verify ARG-to-ENV
# propagation without running the complete tool installation layer.
FROM foundation AS devcontainer
ARG UID_NAME=ubuntu
ARG APP_NAME=project-name

# Keep this contract block in sync with devcontainer-version-contract.
ARG ENGRAM_VERSION=
ARG NODE_MAJOR=
ARG PLAYWRIGHT_VERSION=

ENV ENGRAM_VERSION=${ENGRAM_VERSION}
ENV NODE_MAJOR=${NODE_MAJOR}
ENV PLAYWRIGHT_VERSION=${PLAYWRIGHT_VERSION}

WORKDIR /home/${UID_NAME}
COPY tool-versions.conf ./.devcontainer-install/tool-versions.conf
COPY install/available/ ./.devcontainer-install/available/
COPY install/02-enabled/ ./.devcontainer-install/02-enabled/
COPY install/03-hooks/ ./.devcontainer-install/03-hooks/
COPY install/lib/ ./.devcontainer-install/lib/

RUN chown -R "${UID_NAME}:${UID_NAME}" ./.devcontainer-install \
    && find ./.devcontainer-install -type f -name "*.sh" -exec chmod 0755 {} \; \
    && ./.devcontainer-install/lib/run-installers.sh ./.devcontainer-install/02-enabled \
    && ./.devcontainer-install/lib/run-installers.sh ./.devcontainer-install/03-hooks

USER ${UID_NAME}
WORKDIR /home/${UID_NAME}/${APP_NAME}
CMD ["/bin/bash"]
