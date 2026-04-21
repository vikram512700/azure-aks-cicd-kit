# =============================================================================
# Dockerfile — Node.js Express App (multi-stage, non-root, read-only FS)
# =============================================================================

# --- Stage 1: Build dependencies ---
FROM node:20-alpine AS builder

WORKDIR /build
COPY package.json package-lock.json* ./
RUN npm ci --production 2>/dev/null || npm install --production

# --- Stage 2: Production runtime ---
FROM node:20-alpine

# Security: create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup -h /app

WORKDIR /app

# Copy node_modules from builder
COPY --from=builder /build/node_modules ./node_modules

# Copy application code
COPY index.js .
COPY package.json .

# Set ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose Express port
EXPOSE 3000

# Health check (matches K8s probe)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Run the app
CMD ["node", "index.js"]
