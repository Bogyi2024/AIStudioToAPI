# Single-stage build with Node.js 24 - NO VNC packages
# Build from source: place this Dockerfile in the root of the AIStudioToAPI-main
# source tree (alongside main.js, package.json, src/, configs/, scripts/, ui/),
# along with your pre-generated auth-0.json.
FROM node:24-slim

WORKDIR /app

# System dependencies for Playwright/Camoufox browser only (no xvfb/x11vnc/websockify)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libxss1 \
    libxtst6 \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install dependencies
COPY package*.json ./
RUN npm install --no-audit --no-fund --ignore-scripts \
    && npm cache clean --force

# Download and extract Camoufox browser binary
ARG CAMOUFOX_URL
RUN ARCH=$(uname -m) && \
    if [ -z "$CAMOUFOX_URL" ]; then \
    if [ "$ARCH" = "x86_64" ]; then \
    CAMOUFOX_URL="https://github.com/daijro/camoufox/releases/download/v135.0.1-beta.24/camoufox-135.0.1-beta.24-lin.x86_64.zip"; \
    elif [ "$ARCH" = "aarch64" ]; then \
    CAMOUFOX_URL="https://github.com/daijro/camoufox/releases/download/v135.0.1-beta.24/camoufox-135.0.1-beta.24-lin.arm64.zip"; \
    else \
    echo "Unsupported architecture: $ARCH" && exit 1; \
    fi; \
    fi && \
    mkdir -p camoufox-linux && \
    curl -sSL ${CAMOUFOX_URL} -o camoufox.zip && \
    unzip -q camoufox.zip -d /tmp/cf || true && \
    if [ -f /tmp/cf/camoufox ]; then \
    mv /tmp/cf/* camoufox-linux/; \
    else \
    mv /tmp/cf/*/* camoufox-linux/; \
    fi && \
    rm -rf /tmp/cf camoufox.zip && \
    chmod +x /app/camoufox-linux/camoufox

# Copy application source code
COPY --chown=node:node main.js ./
COPY --chown=node:node vite.config.js ./
COPY --chown=node:node src ./src
COPY --chown=node:node configs ./configs
COPY --chown=node:node scripts ./scripts
COPY --chown=node:node ui ./ui

# Build frontend assets
ARG VERSION
RUN VERSION=${VERSION} npm run build:ui

# Remove dev dependencies
RUN npm prune --omit=dev && npm cache clean --force

USER root

EXPOSE 7860

ENV NODE_ENV=production \
    CAMOUFOX_EXECUTABLE_PATH=/app/camoufox-linux/camoufox \
    API_KEYS=test123



HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD node -e "const port = process.env.PORT || 7860; require('http').get('http://localhost:' + port + '/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)}).on('error', () => process.exit(1));" || exit 1

CMD ["node", "main.js"]
