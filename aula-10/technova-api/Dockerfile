# Stage 1 (deps): instala SOMENTE dependencias de producao.
# Separar isso do codigo faz o cache do Docker reaproveitar esta camada
# enquanto package*.json nao mudar.
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Stage 2 (runtime): imagem final, so com o necessario para rodar.
# Nada de npm, devDependencies, testes ou cache de build.
FROM node:20-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node package*.json server.js ./

# Roda como usuario nao-root (principio do menor privilegio)
USER node
EXPOSE 3000

# wget ja vem no alpine (busybox), entao nao precisa instalar nada
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
