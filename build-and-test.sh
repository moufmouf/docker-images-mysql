#!/usr/bin/env bash

set -xe

# Let's build the "slim" image.
docker build -t thecodingmachine/mysql:${MYSQL_VERSION}-v1 --build-arg MYSQL_VERSION=${MYSQL_VERSION} .

## Post build unit tests

docker stop tcm_mysql_test || true

function startMySql() {
  docker run --rm -d --name=tcm_mysql_test --tmpfs /var/lib/mysql -e MYSQL_ROOT_PASSWORD=foo "$*" thecodingmachine/mysql:${MYSQL_VERSION}-v1
}

function stopMySql() {
  docker stop tcm_mysql_test
}

# Executes SQL (wait for MySQL if not available)
function execSql() {
  set +x
  for i in {30..0}; do
    if docker exec tcm_mysql_test mysql -e "SELECT 1" &> /dev/null; then
      break
    fi
    echo 'MySQL init process in progress...'
    sleep 1
  done
  if [ "$i" = 0 ]; then
    echo >&2 'MySQL init process failed.'
    exit 1
  fi
  set -x

  docker exec tcm_mysql_test mysql -e "$1";
}

startMySql -e MYSQLD_INI_MAX_ALLOWED_PACKET=64M
execSql "SHOW VARIABLES LIKE '%max_allowed_packet%';"  | grep "67108864"
stopMySql

#startMySql -e MYSQL_INI_MAX_ALLOWED_PACKET=64M
#execSql "SHOW VARIABLES LIKE '%max_allowed_packet%';"  | grep "67108864"
#stopMySql

#startMySql -e CLIENT_INI_PASSWORD=foo -e CLIENT_INI_USER=root


## Let's check that the extensions can be built using the "ONBUILD" statement
#docker build -t test/slim_onbuild --build-arg PHP_VERSION="${PHP_VERSION}" --build-arg BRANCH="$BRANCH" --build-arg BRANCH_VARIANT="$BRANCH_VARIANT" tests/slim_onbuild
## This should run ok (the sudo disable environment variables but call to composer proxy does not trigger PHP ini file regeneration)
#docker run --rm test/slim_onbuild php -m | grep sockets
#docker run --rm test/slim_onbuild php -m | grep xdebug
#docker rmi test/slim_onbuild
#
## Post build unit tests
#if [[ $VARIANT == cli* ]]; then CONTAINER_CWD=/usr/src/app; else CONTAINER_CWD=/var/www/html; fi
## Default user is 1000
#RESULT=`docker run --rm thecodingmachine/php:${PHP_VERSION}-${BRANCH}-slim-${BRANCH_VARIANT} id -ur`
#[[ "$RESULT" = "1000" ]]
#
## If mounted, default user has the id of the mount directory
#mkdir user1999 && sudo chown 1999:1999 user1999
#ls -al user1999
#RESULT=`docker run --rm -v $(pwd)/user1999:$CONTAINER_CWD thecodingmachine/php:${PHP_VERSION}-${BRANCH}-slim-${BRANCH_VARIANT} id -ur`
#[[ "$RESULT" = "1999" ]]
#
## Also, the default user can write on stdout and stderr
#docker run --rm -v $(pwd)/user1999:$CONTAINER_CWD thecodingmachine/php:${PHP_VERSION}-${BRANCH}-slim-${BRANCH_VARIANT} bash -c "echo TEST > /proc/self/fd/2"

#sudo rm -rf user1999
#
## and it also works for users with existing IDs in the container
#sudo mkdir -p user33
#sudo cp tests/apache/composer.json user33/
#sudo chown -R 33:33 user33
#ls -al user33
#RESULT=`docker run --rm -v $(pwd)/user33:$CONTAINER_CWD thecodingmachine/php:${PHP_VERSION}-${BRANCH}-slim-${BRANCH_VARIANT} id -ur`
#[[ "$RESULT" = "33" ]]
#RESULT=`docker run --rm -v $(pwd)/user33:$CONTAINER_CWD thecodingmachine/php:${PHP_VERSION}-${BRANCH}-slim-${BRANCH_VARIANT} composer update -vvv`
#sudo rm -rf user33
#
## Let's check that mbstring, mysqlnd and ftp are enabled by default (they are compiled in PHP)
#docker run --rm thecodingmachine/php:${PHP_VERSION}-${BRANCH}-slim-${BRANCH_VARIANT} php -m | grep mbstring
#docker run --rm thecodingmachine/php:${PHP_VERSION}-${BRANCH}-slim-${BRANCH_VARIANT} php -m | grep mysqlnd
#docker run --rm thecodingmachine/php:${PHP_VERSION}-${BRANCH}-slim-${BRANCH_VARIANT} php -m | grep ftp
#docker run --rm thecodingmachine/php:${PHP_VERSION}-${BRANCH}-slim-${BRANCH_VARIANT} php -m | grep PDO
#docker run --rm thecodingmachine/php:${PHP_VERSION}-${BRANCH}-slim-${BRANCH_VARIANT} php -m | grep pdo_sqlite
#
#if [[ $VARIANT == apache* ]]; then
#    # Test if environment variables are passed to PHP
#    DOCKER_CID=`docker run --rm -e MYVAR=foo -p "81:80" -d -v $(pwd):/var/www/html thecodingmachine/php:${PHP_VERSION}-${BRANCH}-slim-${BRANCH_VARIANT}`
#
#    # Let's wait for Apache to start
#    sleep 5
#
#    RESULT=`curl http://localhost:81/tests/test.php`
#    [[ "$RESULT" = "foo" ]]
#    docker stop $DOCKER_CID
#fi

echo "Tests passed with success"
