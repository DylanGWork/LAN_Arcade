import { createApiServer } from './app.js';

const { server, config } = createApiServer();

server.listen(config.port, config.host, () => {
  console.log(`LAN Arcade API listening on http://${config.host}:${config.port}/`);
});
