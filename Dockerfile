FROM sonarqube:latest

USER root

# Download SonarQube plugins
ADD https://github.com/mc1arke/sonarqube-community-branch-plugin/releases/download/1.10.0/sonarqube-community-branch-plugin-1.10.0.jar \
    /opt/sonarqube/extensions/plugins/

# Install tools
RUN apk update && \
    apk add --no-cache curl \
	jq

# Copy the config files and scripts into the image
COPY conf/* conf/
COPY scripts/* bin/

# Configure SonarQube
RUN chown -R sonarqube:sonarqube bin/ conf/ extensions/ \
    && chmod u+x -R bin/ \
    # Disable SonarQube telemetry
    && sed -i 's/#sonar\.telemetry\.enable=true/sonar\.telemetry\.enable=false/' /opt/sonarqube/conf/sonar.properties

# Switch back to an unpriviledged user
USER sonarqube

CMD [ "./bin/entrypoint.bash" ]