FROM rhscl/postgresql-95-rhel7:9.5-6.20

USER 0

# PostgreSQL image for OpenShift.
# Volumes:
#  * /var/lib/psql/data   - Database cluster for PostgreSQL
# Environment:
#  * $POSTGRESQL_USER     - Database user name
#  * $POSTGRESQL_PASSWORD - User's password
#  * $POSTGRESQL_DATABASE - Name of the database to create
#  * $POSTGRESQL_ADMIN_PASSWORD (Optional) - Password for the 'postgres'
#                           PostgreSQL administrative account

COPY root /

# Get prefix path and path to scripts rather than hard-code them in scripts
ENV CURRENT_ROOT=/opt/rh/${ENABLED_COLLECTIONS}/root

# This image must forever use UID 26 for postgres user so our volumes are
# safe in the future. This should *never* change, the last test is there
# to make sure of that.
# rhel-7-server-ose-3.2-rpms is enabled for nss_wrapper until this pkg is
# in base RHEL
RUN    yum -y --setopt=tsflags=nodocs --disablerepo=* --enablerepo=rhel-7-server-rpms install glibc && \
    yum -y --setopt=tsflags=nodocs --disablerepo=* --enablerepo=rhel-7-server-rpms install /usr/share/pgaudit_95-1.0.4-1.rhel7.x86_64.rpm && \
    yum clean all && \
    rm -rf /var/cache/yum && \
    rm -rf /usr/share/pgaudit_95-1.0.4-1.rhel7.x86_64.rpm && \
    ln -s /usr/pgsql-9.5/lib/pgaudit.so ${CURRENT_ROOT}/usr/lib64/pgsql/pgaudit.so && \
    ln -s /usr/pgsql-9.5/share/extension/pgaudit--1.0.sql ${CURRENT_ROOT}/usr/share/pgsql/extension/pgaudit--1.0.sql && \
    ln -s /usr/pgsql-9.5/share/extension/pgaudit.control ${CURRENT_ROOT}/usr/share/pgsql/extension/pgaudit.control && \
    localedef -f UTF-8 -i en_US en_US.UTF-8 && \
    test "$(id postgres)" = "uid=26(postgres) gid=26(postgres) groups=26(postgres)" && \
    /usr/libexec/fix-permissions /var/lib/pgsql && \
    /usr/libexec/fix-permissions /var/run/postgresql

USER 26

ENTRYPOINT ["container-entrypoint"]
CMD ["run-postgresql"]
