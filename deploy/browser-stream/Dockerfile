FROM node:24-bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

COPY debs/ /opt/offline-debs/
RUN rm -f /etc/apt/sources.list /etc/apt/sources.list.d/* \
    && printf '%s\n' 'deb [trusted=yes] file:/opt/offline-debs ./' >/etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ace-of-penguins btanks freedroidrpg liquidwar novnc openbox procps \
        scrot sopwith tuxmath websockify x11-utils x11vnc xdotool xvfb \
    && rm -rf /opt/offline-debs /var/lib/apt/lists/* /var/cache/apt/*

RUN printf '%s\n' '{"name":"novnc","version":"1.3.0"}' >/usr/share/novnc/package.json

RUN usermod --login player --home /home/player --move-home --shell /usr/sbin/nologin node \
    && groupmod --new-name player node \
    && mkdir -p /opt/browser-stream /etc/lan-arcade \
    && chown -R player:player /opt/browser-stream /home/player

COPY --chown=player:player container/ /opt/browser-stream/
COPY browser-stream-games.json /etc/lan-arcade/browser-stream-games.json

USER player
WORKDIR /home/player
EXPOSE 6080
HEALTHCHECK --interval=3s --timeout=2s --start-period=20s --retries=10 \
    CMD ["/usr/bin/python3", "/opt/browser-stream/healthcheck.py"]
ENTRYPOINT ["/usr/bin/python3", "/opt/browser-stream/entrypoint.py"]
