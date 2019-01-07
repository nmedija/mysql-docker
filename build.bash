#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# set defaults
mysql_version=5.7.24
push_images="N"

docker_repo=nmedija/mysql
build_date=$(date +%Y%m%d)

print_usage() {
    errmsg '
Builds the docker image for '${docker_repo}'
Usage: build.bash [options]
Options:
       -h               Shows this help text
       -o               Overwrite plugins if they already exist locally
       -p               Push images to repository
       -v <string>      Specifies the MySQL version base image
'
}


stdmsg() {
    local IFS=" " # needed for "$*"
    printf '%s\n' "$*"
}

errmsg() {
    local IFS=" " # needed for "$*"
    printf '%s\n' "$*" 1>&2
}

trap_exit() {
    local exit_status_code=$?

    if [ $exit_status_code != 0 ]; then
        errmsg 'There was an error while executing this script.'
    fi
}

trap trap_exit EXIT

while getopts ':hopv:' opt
do
    case "$opt" in
        o)  overwrite_plugins="Y" ;;
        p)  push_images="Y" ;;
        v)  mysql_version=${OPTARG} ;;
        h)
            print_usage
            exit 0
            ;;
        :)
            errmsg 'Option -'"$OPTARG"' requires an argument. Use -h for help.'
            exit 1
            ;;
        \?)
            errmsg 'Invalid option: -'"$OPTARG"'. Use -h for help'
            exit 1
            ;;
    esac
done

errmsg "Building image using MySQL version $mysql_version"

docker build \
  --build-arg MYSQL_VERSION="$mysql_version" \
  --tag "${docker_repo}:${mysql_version}-${build_date}" \
  --tag "${docker_repo}:${mysql_version}-latest" \
  "$script_dir/docker"

if [[ "$push_images" == "Y" ]]; then
    docker push "${docker_repo}:${mysql_version}-${build_date}"
    docker push "${docker_repo}:${mysql_version}-latest"
fi
