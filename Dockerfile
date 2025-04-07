# =============================================================================
# Build stage
# =============================================================================
FROM node:18 AS builder

RUN apt-get update && apt-get install -y \
    python3 tini \
    rsync \
    libcairo2-dev libpango1.0-dev \
    libjpeg-dev libgif-dev librsvg2-dev \
    && corepack enable \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone --depth 1 https://github.com/laurent22/joplin.git .

RUN sed --in-place '/onenote-converter/d' ./packages/lib/package.json

RUN --mount=type=cache,target=/build/.yarn/cache \
    --mount=type=cache,target=/build/.yarn/berry/cache \
    BUILD_SEQUENCIAL=1 yarn config set cacheFolder /build/.yarn/cache \
    && yarn install --inline-builds

# =============================================================================
# Production stage
# =============================================================================
FROM node:18-bookworm-slim

ENV UID=1001
ENV GID=1001
ENV USER=joplin
COPY --link --chown=${UID}:${GID} --from=builder /build/packages /home/${USER}/packages
COPY --link --chown=${UID}:${GID} --from=builder /usr/bin/tini /usr/bin/tini
RUN set -eux; \
    groupadd --gid ${GID} ${USER} || true; \
    useradd --uid ${UID} --gid ${GID} --home-dir /home/${USER} --shell /bin/bash --create-home ${USER}; \
    install -d -o ${USER} -g ${USER} -m 700 /home/${USER}

USER ${USER}

ENV NODE_ENV=production
ENV RUNNING_IN_DOCKER=1

EXPOSE 22300/tcp

WORKDIR /home/${USER}/packages/server

ENTRYPOINT ["tini", "--"]
CMD ["yarn", "start-prod"]
