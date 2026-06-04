ARG IMAGE=ubuntu:24.04
FROM ${IMAGE}

ARG HOST_GID=1001
ARG HOST_UID=1001
ARG LOCALE=es_MX.UTF-8
ARG NODE_MAJOR=26
ARG PLATFORM_ARCH=linux-arm64
ARG TZ=America/Mexico_City

ENV DEBIAN_FRONTEND=noninteractive
ENV HOST_GID=${HOST_GID}
ENV HOST_UID=${HOST_UID}
ENV LANG=${LOCALE}
ENV LANGUAGE=${LOCALE}
ENV LC_ALL=${LOCALE}
ENV LOCALE=${LOCALE}
ENV NODE_MAJOR=${NODE_MAJOR}
ENV PLATFORM_ARCH=${PLATFORM_ARCH}
ENV TZ=${TZ}

COPY scripts/ /usr/local/share/devcontainer-scripts/

RUN find /usr/local/share/devcontainer-scripts -type f -name "*.sh" -exec chmod 0755 {} \; \
    && find /usr/local/share/devcontainer-scripts -type f -name "*.sh" | sort | while read -r script; do \
        echo ""; \
        echo "============================================================"; \
        echo "Running: ${script}"; \
        echo "============================================================"; \
        "${script}"; \
    done

USER ubuntu
WORKDIR /home/ubuntu/code
CMD ["/bin/bash"]