ARG IMAGE=ubuntu:24.04
FROM ${IMAGE}

ARG ENGRAM_VERSION=1.16.1
ARG HOST_GID=1001
ARG HOST_UID=1001
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
COPY scripts/ ./.devcontainer-scripts/

RUN chown -R "${UID_NAME}:${UID_NAME}" ./.devcontainer-scripts \
    && find ./.devcontainer-scripts -type f -name "*.sh" -exec chmod 0755 {} \; \
    && find ./.devcontainer-scripts -type f -name "*.sh" | sort | while read -r script; do \
        echo ""; \
        echo "============================================================"; \
        echo "Running: ${script}"; \
        echo "============================================================"; \
        DEVCONTAINER_PHASE=build "${script}"; \
    done

USER ${UID_NAME}
WORKDIR /home/${UID_NAME}/code
CMD ["/bin/bash"]