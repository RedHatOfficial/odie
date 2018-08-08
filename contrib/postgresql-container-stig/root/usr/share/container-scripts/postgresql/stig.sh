# Configuration settings.
export POSTGRESQL_LOG_LINE_PREFIX=${POSTGRESQL_LOG_LINE_PREFIX:-'< %m %a %u %d %c %s %r >'}
export POSTGRESQL_SYSLOG_FACILITY=${POSTGRESQL_SYSLOG_FACILITY:-'LOCAL0'}
export ENABLE_SYSLOG=${ENABLE_SYSLOG:-false}

export POSTGRESQL_HBA_FILE=$HOME/stig-custom-pg_hba.conf
export POSTGRESQL_IDENT_FILE=$HOME/stig-custom-pg_ident.conf
export POSTGRESQL_CONFIG_FILE_OVERRIDES=$HOME/overrides/replacement.properties


initialze_database_pgaudit () {
  psql --command "CREATE EXTENSION pgaudit;"
  touch $PGDATA/pgaudit.enabled
}

initialze_database_pgcrypto () {
  psql --command "CREATE EXTENSION pgcrypto;"
  touch $PGDATA/pgcrypto.enabled
}

# New config is generated every time a container is created. It only contains
# additional custom settings and is included from $PGDATA/postgresql.conf.
function generate_postgresql_config_preload_pgaudit() {
  envsubst \
      < "${CONTAINER_SCRIPTS_PATH}/stig-custom-pgaudit-postgresql.conf.template" \
      >> "${POSTGRESQL_CONFIG_FILE}"
}

function generate_postgresql_config_append_stig() {
  envsubst \
      < "${CONTAINER_SCRIPTS_PATH}/stig-custom-postgresql.conf.template" \
      >> "${POSTGRESQL_CONFIG_FILE}"

  # copy STIG configured pg_hba.conf and pg_ident.conf file to home directory
  envsubst \
      < "${CONTAINER_SCRIPTS_PATH}/stig-custom-pg_hba.conf.template" \
      > "${POSTGRESQL_HBA_FILE}"
  envsubst \
      < "${CONTAINER_SCRIPTS_PATH}/stig-custom-pg_ident.conf.template" \
      > "${POSTGRESQL_IDENT_FILE}"

  if [ "${ENABLE_SYSLOG}" == "true" ]; then
    envsubst \
        < "${CONTAINER_SCRIPTS_PATH}/stig-custom-syslog-postgresql.conf.template" \
        >> "${POSTGRESQL_CONFIG_FILE}"
  fi

  if [ -f $POSTGRESQL_CONFIG_FILE_OVERRIDES ]; then
    # replace config parameters with overridden values
    while read -u 10 p; do
      set -- `echo $p | tr '=' ' '`
      key=$1
      value=$2
      sed -i '/^'$key'/c\'"$key = $value \# customzed with application specific settings by vendor." "${POSTGRESQL_CONFIG_FILE}"
    done 10<$POSTGRESQL_CONFIG_FILE_OVERRIDES
  fi

}

set_user_max_connections() {
  # V-72863
  if [ -v POSTGRESQL_USER ]; then
    psql -c "ALTER ROLE ${POSTGRESQL_USER} CONNECTION LIMIT ${POSTGRESQL_MAX_CONNECTIONS}";
  fi
  psql -c "ALTER ROLE 'postgres' CONNECTION LIMIT ${POSTGRESQL_MAX_CONNECTIONS}";
}

link_secrets_to_data_dir() {
  # because secrets cannot be set with permissions until OCP 3.7
  for i in {'server.key','server.crt','root.crt','root.crl'}; do
    echo "$i"
    {
      cp -f /security/ssl/$i $PGDATA
      chmod 600 $PGDATA/$i
      #chown 26:26 $PGDATA/$i
    } || {
      echo "Problem configuring $i"
    }
  done
}
