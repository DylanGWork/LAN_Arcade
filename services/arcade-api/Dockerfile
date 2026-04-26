FROM node:18-bookworm-slim AS build

WORKDIR /app
RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json ./
COPY packages/shared/package.json packages/shared/package.json
COPY services/arcade-api/package.json services/arcade-api/package.json
RUN npm ci

COPY packages/shared packages/shared
COPY services/arcade-api services/arcade-api
RUN npm run build -w @lan-arcade/shared \
  && npm run build -w @lan-arcade/arcade-api

FROM node:18-bookworm-slim AS runtime

WORKDIR /app
ENV NODE_ENV=production
ENV ARCADE_API_HOST=0.0.0.0
ENV ARCADE_API_PORT=3100
ENV LAN_ARCADE_DB_PATH=/var/lib/lan-arcade/lan-arcade.sqlite
ENV LAN_ARCADE_CATALOG_PATH=/var/www/html/mirrors/games/catalog.json
ENV LAN_ARCADE_FILTERS_PATH=/var/www/html/mirrors/games/admin.filters.json

COPY --from=build /app/package.json /app/package-lock.json ./
COPY --from=build /app/packages/shared/package.json packages/shared/package.json
COPY --from=build /app/services/arcade-api/package.json services/arcade-api/package.json
RUN npm ci --omit=dev --omit=optional \
  --workspace @lan-arcade/shared \
  --workspace @lan-arcade/arcade-api

COPY --from=build /app/packages/shared/dist packages/shared/dist
COPY --from=build /app/services/arcade-api/dist services/arcade-api/dist

EXPOSE 3100
CMD ["npm", "run", "start", "-w", "@lan-arcade/arcade-api"]
