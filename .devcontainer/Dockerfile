ARG IMAGE=ubuntu:24.04
FROM ${IMAGE} AS foundation

ARG LOCALE=es_MX.UTF-8
ARG TZ=America/Mexico_City
ARG UID_NAME=ubuntu

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=${LOCALE}
ENV LANGUAGE=${LOCALE}
ENV LC_ALL=${LOCALE}
ENV LOCALE=${LOCALE}
ENV TZ=${TZ}

WORKDIR /home/${UID_NAME}
COPY install/01-core/ ./.devcontainer-install/01-core/
COPY install/lib/common.sh ./.devcontainer-install/lib/common.sh

RUN chown -R "${UID_NAME}:${UID_NAME}" ./.devcontainer-install \
    && find ./.devcontainer-install -type f -name "*.sh" -exec chmod 0755 {} \; \
    && find -L ./.devcontainer-install/01-core -maxdepth 1 -type f -name "*.sh" \
        | sort | while read -r script; do \
            echo ""; \
            echo "============================================================"; \
            echo "Running: ${script}"; \
            echo "============================================================"; \
            DEVCONTAINER_PHASE=build bash "${script}"; \
        done

FROM ${IMAGE} AS devcontainer-version-contract

# Library versions. The canonical default lives in the install script
# that consumes the value; the Dockerfile only carries the override
# point (--build-arg VAR=...) and the runtime ENV for re-installs.
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
    && for group in 02-enabled 03-hooks; do \
        if [ -d "./.devcontainer-install/${group}" ]; then \
            find -L "./.devcontainer-install/${group}" -maxdepth 1 -type f -name "*.sh" \
                | sort | while read -r script; do \
                echo ""; \
                echo "============================================================"; \
                echo "Running: ${script}"; \
                echo "============================================================"; \
                DEVCONTAINER_PHASE=build bash "${script}"; \
            done; \
        fi; \
    done

USER ${UID_NAME}
WORKDIR /home/${UID_NAME}/${APP_NAME}
CMD ["/bin/bash"]
