#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

mysqladmin --defaults-extra-file=/etc/mysql/healthcheck.cnf ping || exit 1
exit 0
