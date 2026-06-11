ARG IMAGE=ubuntu:24.04
FROM ${IMAGE}

# Library versions. The canonical default lives in the install script
# that consumes the value; the Dockerfile only carries the override
# point (--build-arg VAR=...) and the runtime ENV for re-installs.
ARG ENGRAM_VERSION=
ARG NODE_MAJOR=
ARG PLAYWRIGHT_VERSION=

# Runtime locale and timezone. These set the container's LANG/LC_ALL/TZ
# at runtime, so the defaults must stay in the Dockerfile — moving
# them to a script would not reach the runtime ENV.
ARG LOCALE=es_MX.UTF-8
ARG TZ=America/Mexico_City

# Identity of the single devcontainer user.
ARG UID_NAME=ubuntu

ENV DEBIAN_FRONTEND=noninteractive
ENV ENGRAM_VERSION=${ENGRAM_VERSION}
ENV NODE_MAJOR=${NODE_MAJOR}
ENV PLAYWRIGHT_VERSION=${PLAYWRIGHT_VERSION}
ENV LANG=${LOCALE}
ENV LANGUAGE=${LOCALE}
ENV LC_ALL=${LOCALE}
ENV LOCALE=${LOCALE}
ENV TZ=${TZ}

WORKDIR /home/${UID_NAME}
COPY install/ ./.devcontainer-install/

RUN chown -R "${UID_NAME}:${UID_NAME}" ./.devcontainer-install \
    && find ./.devcontainer-install -type f -name "*.sh" -exec chmod 0755 {} \; \
    && for group in 01-core 02-enabled 03-hooks; do \
        if [ -d "./.devcontainer-install/${group}" ]; then \
            find -L "./.devcontainer-install/${group}" -maxdepth 1 -type f -name "*.sh" \
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