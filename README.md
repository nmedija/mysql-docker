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
././build.bash -p
```

## How to run it
```
docker run -it --rm --name nmedija-mysql -p 3306:3306 \
    -e MYSQL_ROOT_PASSWORD="N0tS3cUr3" \
    -e MYSQL_REMOTE_ADMIN_USER="admin" \
    -e MYSQL_REMOTE_ADMIN_PASSWORD="Pl3as3Chang3Me" \
    nmedija/mysql:5.7.24-latest
```    
