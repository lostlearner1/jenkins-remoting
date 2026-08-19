FROM jenkins/jenkins:lts-jdk21

USER root
# Install curl, git, jq if needed for diagnostics
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    jq \
    && rm -rf /var/lib/apt/lists/*

USER jenkins

# Pre-install plugins using jenkins-plugin-cli
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Disable setup wizard and configure JCasC path
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Dhudson.model.DirectoryBrowserSupport.CSP="
ENV CASC_JENKINS_CONFIG="/var/jenkins_home/casc"
