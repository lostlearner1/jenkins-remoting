FROM jenkins/ssh-agent:jdk21

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    tar \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Keep entrypoint as root so setup-sshd can start openssh-server
