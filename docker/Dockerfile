FROM ubuntu:xenial

MAINTAINER Nat Medija

ARG MYSQL_VERSION

ENV MYSQL_RUN_DIR "/var/run/mysqld"
ENV MYSQL_LOG_DIR "/var/log/mysqld"
ENV MYSQL_DATA_DIR "/data/mysql"
ENV MYSQL_BACKUP_DIR "/backup/mysql"

RUN apt-get update \
    && groupadd -r mysql \
    && useradd -r -g mysql mysql \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server=${MYSQL_VERSION}-* \
    && mkdir -p ${MYSQL_RUN_DIR} \
    && mkdir -p ${MYSQL_LOG_DIR} \
    && mkdir -p ${MYSQL_DATA_DIR} \
    && mkdir -p ${MYSQL_BACKUP_DIR} \
    && chown mysql:mysql ${MYSQL_RUN_DIR} \
    && chown mysql:mysql ${MYSQL_LOG_DIR} \
    && chown mysql:mysql ${MYSQL_DATA_DIR} \
    && chown mysql:mysql ${MYSQL_BACKUP_DIR} \
    && chown -R mysql:mysql /etc/mysql

COPY ./entrypoint.bash /.
COPY ./healthcheck.bash /.

VOLUME [ "/data" ]
VOLUME [ "/backup"]

ENTRYPOINT ["/entrypoint.bash"]

HEALTHCHECK --interval=5s --timeout=1m --retries=5 CMD [ "/healthcheck.bash" ]

EXPOSE 3306

USER mysql

CMD [ "mysqld_safe" ]
