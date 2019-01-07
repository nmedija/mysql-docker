#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

set +o xtrace

MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"
MYSQL_REMOTE_ADMIN_USER="${MYSQL_REMOTE_ADMIN_USER:-}"
MYSQL_REMOTE_ADMIN_PASSWORD="${MYSQL_REMOTE_ADMIN_PASSWORD:-}"
MYSQL_DATABASE="${MYSQL_DATABASE:-}"
MYSQL_DATABASE_USER="${MYSQL_DATABASE_USER:-}"
MYSQL_DATABASE_PASSWORD="${MYSQL_DATABASE_PASSWORD:-}"
MYSQL_CUSTOM_INIT_SQL="${MYSQL_CUSTOM_INIT_SQL:-}"

set -o xtrace

stdmsg() {
    local IFS=" " # needed for "$*"
    printf '%s\n' "$*"
}

errmsg() {
    local IFS=" " # needed for "$*"
    printf '%s\n' "$*" 1>&2
}

get_config() {
    local config="$1"
    value=$(mysqld --help --verbose 2>/dev/null | grep "^$config" | tr -s [:blank:] | cut -d' ' -f2)
    stdmsg "$value"
}

check_secret_from_file() {
    # retrieves the secret value from file if the path is specified
    # in the _FILE environment variable. If it fails for some reason
    # the variable will remain intact
    var_name="$1"
    var_name_file="${var_name}_FILE"

    set +o errexit
    file_env_exists=$(env | grep "^${var_name_file}=.*" 2>&1 > /dev/null && stdmsg "1")
    set -o errexit

    if [[ "$file_env_exists" == "1" ]]; then

        if [ -n "${!var_name}" ] && [ -n "${!var_name_file}" ]; then
            errmsg "ERROR: ${var_name} and ${var_name_file} variables are mutually exclusive"
            exit 1
        fi

        if [[ -n "${!var_name_file}" ]] && [ -f "${!var_name_file}" ]; then
            # get the value from file
            export "$var_name"="$(< "${!var_name_file}")"
        fi
    fi
}

check_database_status() {
    local retval=1
    mysqladmin -u root status >/dev/null 2>&1
    retval=$?
    if [ "$retval" != 0 ] ; then
        mysqladmin --defaults-file="/etc/mysql/entrypoint.cnf" status >/dev/null 2>&1
        retval=$?
    fi
    return "$retval"
}

trap_exit() {
    local exit_status_code=$?
    if [ $exit_status_code != 0 ]; then
        errmsg 'Unable to successfully complete entrypoint.bash'
    fi
}

trap trap_exit EXIT

wait_until_ready() {
    retries="$1"
    interval="$2"
    count=0
    while [[ "$count" -lt "$retries" ]]; do
        count=$((count+1))
        sleep "$interval"
        if check_database_status ; then
            return 0
        fi
    done
    errmsg "Timed out trying to connect to MySQL locally. Aborting."
    exit 1
}

setup_directories () {
    mkdir -p ${MYSQL_RUN_DIR}
    chown -R mysql:mysql ${MYSQL_RUN_DIR}
    chmod 755 ${MYSQL_RUN_DIR}

    mkdir -p ${MYSQL_LOG_DIR}
    chown -R mysql:mysql ${MYSQL_LOG_DIR}
    chmod 755 ${MYSQL_LOG_DIR}

    mkdir -p "$MYSQL_DATA_DIR"
    chown -R mysql:mysql "$MYSQL_DATA_DIR"
    chmod 755 ${MYSQL_DATA_DIR}

    mkdir -p "$MYSQL_BACKUP_DIR"
    chown -R mysql:mysql "$MYSQL_BACKUP_DIR"
    chmod 755 ${MYSQL_BACKUP_DIR}
}

change_root_password() {
    set +o xtrace
    wait_until_ready 30 1
    mysql -uroot << EOF
        SET @@SESSION.SQL_LOG_BIN=0;
  			ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
  			GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION ;
  			FLUSH PRIVILEGES ;
EOF
    set -o xtrace
}

run_custom_init_sql() {
    if [ -n "$MYSQL_CUSTOM_INIT_SQL" ]; then
        wait_until_ready 30 1
        mysql --defaults-file=/etc/mysql/entrypoint.cnf < "$MYSQL_CUSTOM_INIT_SQL"
    fi
}

create_new_user() {
    set +o xtrace
    local auth="${1:--uroot}"
    local username="$2"
    local password="${3:-}"
    local database="${4:-}"
    local host="${5,-localhost}"
    local admin="${6:-N}"

    mysql "$auth" -e "CREATE USER IF NOT EXISTS '${username}'@'${host}' IDENTIFIED BY '${password}';"

    if [-n "$database" ]; then
        mysql $auth -e "CREATE DATABASE IF NOT EXISTS $database;"
        mysql $auth -e "GRANT ALL PRIVILEGES on $database.* TO '${username}'@'${host}' WITH GRANT OPTION;"
        mysql $auth -e "FLUSH PRIVILEGES;"
    fi

    if [[ "$admin" == "Y" ]]; then
        mysql $auth -e "GRANT ALL PRIVILEGES on *.* TO '${username}'@'${host}' WITH GRANT OPTION;"
        mysql $auth -e "FLUSH PRIVILEGES;"
    fi
    set -o xtrace
}


create_healthcheck_user() {
    create_new_user "--defaults-file=/etc/mysql/entrypoint.cnf" healthcheck "" "" "localhost" "N"
}

create_remote_admin_user() {
    set +o xtrace
    if [[ "$MYSQL_REMOTE_ADMIN_USER" != "" ]] && [[ "$MYSQL_REMOTE_ADMIN_PASSWORD" != "" ]]; then
        create_new_user "--defaults-file=/etc/mysql/entrypoint.cnf" "$MYSQL_REMOTE_ADMIN_USER" "$MYSQL_REMOTE_ADMIN_PASSWORD" "" "%" "Y"
    else
        errmsg "WARNING: Both MYSQL_REMOTE_ADMIN_USER and MYSQL_REMOTE_ADMIN_PASSWORD values are needed to create a remote admin user."
    fi
    set -o xtrace
}

create_database_and_user() {
    if [ -n "$MYSQL_DATABASE" ] && [ -n "$MYSQL_DATABASE_USER" ]; then
        create_new_user "--defaults-file=/etc/mysql/entrypoint.cnf" "$MYSQL_DATABASE_USER" "$MYSQL_DATABASE_PASSWORD" "$MYSQL_DATABASE" "%" "N"
    fi
}

check_envs() {
    set +o xtrace
    check_secret_from_file "MYSQL_ROOT_PASSWORD"
    if [ -z "$MYSQL_ROOT_PASSWORD" ];  then
        MYSQL_ROOT_PASSWORD=$(openssl rand -base64 16)
        errmsg "WARNING: MYSQL_ROOT_PASSWORD was not set. A random root password has been generated"
    fi

    check_secret_from_file "MYSQL_REMOTE_ADMIN_PASSWORD"
    if [ -z "$MYSQL_REMOTE_ADMIN_USER" ]; then
        errmsg "WARNING: MYSQL_REMOTE_ADMIN_USER is not set. Admin access only available inside container"
    fi

    check_secret_from_file "MYSQL_DATABASE_PASSWORD"
    set -o xtrace
}

configure_parameters() {
    cat >> "/etc/mysql/my.cnf" << EOF
    [mysqld]
    bind_address = 0.0.0.0
    datadir = $MYSQL_DATA_DIR
    general_log_file = $MYSQL_LOG_DIR/mysql.log
    log_error = $MYSQL_LOG_DIR/error.log
EOF

    cat > /etc/mysql/entrypoint.cnf << EOF
    [client]
    host = localhost
    user = root
    password = ${MYSQL_ROOT_PASSWORD}
    socket = ${MYSQL_RUN_DIR}/mysqld.sock
EOF
    chown mysql:mysql /etc/mysql/entrypoint.cnf
    chmod 755 /etc/mysql/entrypoint.cnf


    cat > /etc/mysql/healthcheck.cnf << EOF
    [client]
    host = localhost
    user = healthcheck
    password =
    socket = ${MYSQL_RUN_DIR}/mysqld.sock
EOF
    chown mysql:mysql /etc/mysql/healthcheck.cnf
    chmod 700 /etc/mysql/healthcheck.cnf

    # Check configuration if valid
    local status=0
    output=$(mysqld --verbose --help 2>&1 >/dev/null) || status=$?
    if [[ "$status" != "0" ]]; then
        errmsg "Unable to start MySQL. Check configuration"
        errmsg "$output"
        exit 1
    fi
}

initialize_database() {
    local db_init=0
    if [ ! -d "$MYSQL_DATA_DIR/mysql" ]; then
        errmsg "Initializing database"
        mysqld --initialize-insecure --user=mysql --datadir="$MYSQL_DATA_DIR"
        db_init=1
    fi

    socket=$(get_config 'socket')
    errmsg "Starting up database"
    mysqld --daemonize --skip-networking --socket="$socket"

    if [[ "$db_init" == 1 ]]; then
        change_root_password
        create_remote_admin_user
        create_healthcheck_user
        create_database_and_user
        run_custom_init_sql
    fi

    errmsg "Shutting down database"
    mysqladmin --defaults-file=/etc/mysql/entrypoint.cnf shutdown
}

# check if command starts with 'mysqld_safe' or '-', if so setup database
# and start it
init_flag=0
if [[ "$1" == "mysqld_safe" ]]; then
    init_flag=1
elif [[ "$1" =~ ^-.* ]]; then
    init_flag=1
    set -- mysqld_safe "$@"
fi

if [[ "$init_flag" == "1" ]]; then
    errmsg $(env | grep "^MYSQL_.*")
    check_envs
    setup_directories
    configure_parameters
    initialize_database
    # disable root access without password
    rm -Rf /etc/mysql/entrypoint.cnf
fi

exec "$@"
