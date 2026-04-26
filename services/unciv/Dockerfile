FROM eclipse-temurin:21-jre

ARG UNCIV_VERSION=4.20.1

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/unciv
RUN curl -fsSL \
  "https://github.com/yairm210/Unciv/releases/download/${UNCIV_VERSION}/UncivServer.jar" \
  -o /opt/unciv/UncivServer.jar

RUN useradd --system --uid 10002 --home-dir /var/lib/unciv unciv \
  && mkdir -p /var/lib/unciv \
  && chown -R unciv:unciv /var/lib/unciv /opt/unciv

COPY services/unciv/entrypoint.sh /usr/local/bin/unciv-entrypoint.sh
RUN chmod +x /usr/local/bin/unciv-entrypoint.sh

USER unciv
WORKDIR /var/lib/unciv
VOLUME ["/var/lib/unciv"]

EXPOSE 8090/tcp

ENTRYPOINT ["/usr/local/bin/unciv-entrypoint.sh"]
