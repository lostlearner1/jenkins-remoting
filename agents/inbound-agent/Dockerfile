FROM jenkins/inbound-agent:alpine-jdk21

USER root
RUN apk add --no-cache \
    curl \
    grep \
    sed \
    bash \
    git

COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

USER jenkins

ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
