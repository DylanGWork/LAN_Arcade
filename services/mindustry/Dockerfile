FROM eclipse-temurin:17-jre

ARG MINDUSTRY_VERSION=v157.4

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/mindustry
RUN curl -fsSL \
  "https://github.com/Anuken/Mindustry/releases/download/${MINDUSTRY_VERSION}/server-release.jar" \
  -o /opt/mindustry/server-release.jar

RUN useradd --system --uid 10001 --home-dir /var/lib/mindustry mindustry \
  && mkdir -p /var/lib/mindustry \
  && chown -R mindustry:mindustry /var/lib/mindustry /opt/mindustry

COPY services/mindustry/entrypoint.sh /usr/local/bin/mindustry-entrypoint.sh
RUN chmod +x /usr/local/bin/mindustry-entrypoint.sh

USER mindustry
WORKDIR /var/lib/mindustry
VOLUME ["/var/lib/mindustry"]

EXPOSE 6567/tcp 6567/udp

ENTRYPOINT ["/usr/local/bin/mindustry-entrypoint.sh"]
