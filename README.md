# mysql-docker
This contains scripts to create a MySQL docker image

## Building the image
```
$ ./build.bash -h

Builds the docker image for nmedija/mysql
Usage: build.bash [options]
Options:
       -h               Shows this help text
       -o               Overwrite plugins if they already exist locally
       -p               Push images to repository
       -v <string>      Specifies the Grafana version base image
```
To build the image and push it to dockerhub registry
```
./build.bash -p
```

## Environment Variables

| Environment                 | Default                | Description |
| --------------------------- | ---------------------- | ----------- |
| MYSQL_RUN_DIR               | "/var/run/mysqld"      | MySQL runtime directory |
| MYSQL_LOG_DIR               | "/var/log/mysqld"      | MySQL log directory |
| MYSQL_DATA_DIR              | "/data/mysql"          | MySQL data directory |
| MYSQL_BACKUP_DIR            | "/backup/mysql"        | MySQL backup directory
| MYSQL_ROOT_PASSWORD         |                        | If not specified, a random password will be generated |
| MYSQL_REMOTE_ADMIN_USER     |                        | If not specified, the database will not have remote admin access. |
| MYSQL_REMOTE_ADMIN_PASSWORD |                        | This is required if MYSQL_REMOTE_ADMIN_USER is specified |
| MYSQL_DATABASE              |                        | The database to create during initialization |
| MYSQL_DATABASE_USER         |                        | The database user to create during initialization|
| MYSQL_DATABASE_PASSWORD     |                        | The password for the user specified in MYSQL_DATABASE_USER |
| MYSQL_CUSTOM_INIT_SQL       |                        | This is a custom initialization SQL script that will be executed at startup |

NOTES:
1. If the MYSQL_ROOT_PASSWORD and MYSQL_REMOTE_ADMIN_USER variables are not specified, the database will not have admin access.
2. To secure passwords, a file path can be specified which will hold the secret . For example, instead of specifying the root password in the
   MYSQL_ROOT_PASSWORD, the password can be stored in a file and the file path is set in the MYSQL_ROOT_PASSWORD_FILE variable.
   ```
   $ echo "password1" > ~/secrets/mysql.rootpassword

   $ docker run -it --rm --name nmedija-mysql -p 3306:3306 \
        -e MYSQL_ROOT_PASSWORD_FILE=/secrets/.rootpassword
        -v ~/secrets/mysql:/secrets
        nmedija/mysql:5.7.24-latest
   ```

## Running as a server
```
$ docker run -it --rm --name nmedija-mysql -p 3306:3306 \
      -e MYSQL_ROOT_PASSWORD="NotSecure" \
      -e MYSQL_REMOTE_ADMIN_USER="admin" \
      -e MYSQL_REMOTE_ADMIN_PASSWORD="PleaseChangeMe"
      -e MYSQL_DATABASE="grafana" \
      -e MYSQL_DATABASE_USER="grafana" \
      -e MYSQL_DATABASE_USER_PASSWORD="DoNotUseThisPassword" \
      nmedija/mysql:5.7.24-latest
```    

## Running as a client
```
docker run -it --rm --name mysql-client \
    --net=host \
    nmedija/mysql:5.7.24-latest \
    mysql -h 127.0.0.1 -uadmin -pThisIsMyAdminPassword
```          
