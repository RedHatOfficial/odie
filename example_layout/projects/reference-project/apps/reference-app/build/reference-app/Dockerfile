FROM jboss-eap-6/eap64-openshift:1.4

MAINTAINER Red Hat Consulting

USER root

# The following docker COPY <src> <dest> commands will copy the contents
#   of the distinct application folders in to their respective
#   directories. If the <src> directories are empty, i.e. the application
#   does not require any modules, then comment out the line. If you fail to
#   comment out the line, and the directory is left empty, you may see the
#   below error:
#     error: build error: lstat modules/: no such file or directory
#   This is because docker COPY copies the conents of the directory, not the
#   directory itself.
#   https://docs.docker.com/engine/reference/builder/#copy
COPY deployments/ /deployments/
COPY modules/ /opt/eap/modules/
COPY configuration/ /opt/eap/standalone/configuration/
COPY bin/ /opt/eap/bin/

RUN ln -s /data/* /opt/eap/ && chmod -R g+rw /opt/eap && chown -R jboss /opt/eap && chmod 755 /opt/eap/bin/start-jboss.sh

USER 185

EXPOSE 8443

#CMD ["/opt/eap/bin/openshift-launch.sh"]
CMD ["/opt/eap/bin/start-jboss.sh"]
