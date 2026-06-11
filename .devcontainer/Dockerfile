ARG IMAGE=ubuntu:24.04
FROM ${IMAGE}

ARG ENGRAM_VERSION=1.16.1
ARG HOST_GID=1000
ARG HOST_UID=1000
ARG LOCALE=es_MX.UTF-8
ARG NODE_MAJOR=26
ARG PLATFORM_ARCH=linux-arm64
ARG PLAYWRIGHT_VERSION=1.60.0
ARG TZ=America/Mexico_City
ARG UID_NAME=ubuntu

ENV DEBIAN_FRONTEND=noninteractive
ENV ENGRAM_VERSION=${ENGRAM_VERSION}
ENV HOST_GID=${HOST_GID}
ENV HOST_UID=${HOST_UID}
ENV LANG=${LOCALE}
ENV LANGUAGE=${LOCALE}
ENV LC_ALL=${LOCALE}
ENV LOCALE=${LOCALE}
ENV NODE_MAJOR=${NODE_MAJOR}
ENV PLATFORM_ARCH=${PLATFORM_ARCH}
ENV PLAYWRIGHT_VERSION=${PLAYWRIGHT_VERSION}
ENV TZ=${TZ}

WORKDIR /home/${UID_NAME}
COPY install/ ./.devcontainer-install/

RUN chown -R "${UID_NAME}:${UID_NAME}" ./.devcontainer-install \
    && find ./.devcontainer-install -type f -name "*.sh" -exec chmod 0755 {} \; \
    && for group in core enabled hooks; do \
        if [ -d "./.devcontainer-install/${group}" ]; then \
            find "./.devcontainer-install/${group}" -type f -name "*.sh" \
                -not -name "*.disable" \
                -not -name "*.disabled" \
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
WORKDIR /home/${UID_NAME}/code
CMD ["/bin/bash"]