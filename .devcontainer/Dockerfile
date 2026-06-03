ARG IMAGE=ubuntu:24.04
FROM ${IMAGE}

ARG TZ=America/Mexico_City
ARG LOCALE=es_MX.UTF-8
ARG HOST_UID=1001
ARG HOST_GID=1001
ARG PLATFORM_ARCH=linux-arm64

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=${TZ}
ENV LANG=${LOCALE}
ENV LC_ALL=${LOCALE}
ENV LOCALE=${LOCALE}
ENV LANGUAGE=${LOCALE}
ENV HOST_UID=${HOST_UID}
ENV HOST_GID=${HOST_GID}

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        jq \
        locales \
        # python3 \
        # python3-pip \
        # pipx \
        # python3-venv \
        nodejs \
        npm \
        sudo \
        tree \
        tzdata \
    # Configure timezone
    && ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone \
    && dpkg-reconfigure -f noninteractive tzdata \
    # Configure locales
    && sed -i "s/# ${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen \
    && locale-gen ${LOCALE} \
    && update-locale LANG=${LOCALE} LANGUAGE=${LOCALE} LC_ALL=${LOCALE}
    # Install Task
RUN curl -1sLf 'https://dl.cloudsmith.io/public/task/task/setup.deb.sh' | sudo -E bash \
    && apt-get install -y --no-install-recommends task \
    # Install Playwright CLI and browsers/deps
    && npm install -g playwright@latest \
    # Install skills
    && npm install -g skills \
    && npx -y playwright@latest install --with-deps \
    # Clean install
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# RUN pipx ensurepath

# Create a 'vscode' user compatible with Dev Containers (idempotent)
RUN if [ "${HOST_UID}" != "1000" ]; then \
        groupadd -g "${HOST_GID}" vscode 2>/dev/null || true && \
        if ! id -u vscode >/dev/null 2>&1; then \
            useradd -u "${HOST_UID}" -g "${HOST_GID}" -m -s /bin/bash vscode 2>/dev/null || true; \
        fi && \
        echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-vscode && \
        chmod 0440 /etc/sudoers.d/90-vscode ; \
    fi && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/95-ubuntu && \
    chmod 0440 /etc/sudoers.d/95-ubuntu

USER ubuntu
WORKDIR /home/ubuntu/code
