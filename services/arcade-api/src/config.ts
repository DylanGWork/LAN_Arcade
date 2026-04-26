import path from 'node:path';

export interface ApiConfig {
  port: number;
  host: string;
  databasePath: string;
  catalogPath: string;
  filtersPath: string;
  arcadeName: string;
}

export function loadConfig(overrides: Partial<ApiConfig> = {}): ApiConfig {
  const catalogPath = process.env.LAN_ARCADE_CATALOG_PATH || '/var/www/html/mirrors/games/catalog.json';
  return {
    port: Number.parseInt(process.env.ARCADE_API_PORT || '3100', 10),
    host: process.env.ARCADE_API_HOST || '0.0.0.0',
    databasePath: process.env.LAN_ARCADE_DB_PATH || '/var/lib/lan-arcade/lan-arcade.sqlite',
    catalogPath,
    filtersPath: process.env.LAN_ARCADE_FILTERS_PATH || path.join(path.dirname(catalogPath), 'admin.filters.json'),
    arcadeName: process.env.ARCADE_NAME || 'LAN Arcade',
    ...overrides
  };
}
