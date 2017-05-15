#!/bin/bash
# Jar Dockerfile
read -d '' simpleDockerfile <<-EOF
FROM java:8
EXPOSE 8080
ADD /target/*.jar entry_point.jar
ENTRYPOINT ["java", "-jar", "entry_point.jar"]
EOF
read -d '' basicDockerfile <<-EOF
FROM tomcat:8
RUN rm -rf /usr/local/tomcat/webapps/ROOT
ADD target/*.war /usr/local/tomcat/webapps/ROOT.war
EOF
# Simple Jar-based dockerizing
simpleBasicDockerizing()
{
  case $1 in
  s)
    echo mode: simple \(jar\)
    echo "$simpleDockerfile" > Dockerfile;;
  b)
    echo mode: basic \(tomcat only\)
    echo "$basicDockerfile" > Dockerfile
  esac 
  if [ -z $2 ]
  then
  mavenCleanInstall
  fi
  if [ "$2" != no-rebuild ]
  then
  mavenPack
  docker build -f Dockerfile -t $app_name .
  fi
  dockerRun
}
# Compose dockerizing using Tomcat 8 and Postgresql
composeDockerizing()
{
  echo mode: compose \(tomcat+postgresql\)
  if [ -z $1 ]
  then
    echo "$basicDockerfile" > Dockerfile
    echo Please input username for database access:
    read db_uname
    echo Password for $db_uname
    read db_pass
    read -d '' composeFile <<-EOF
version: '2'
services:
  db:
    restart: always
    image: postgres:9.4
    ports:
      - "$db_port:5432"
    environment:
      - DEBUG=false
      - POSTGRES_USER=$db_uname
      - POSTGRES_PASSWORD=$db_pass
    volumes:
      - /srv/docker/postgresql:/var/lib/postgresql
  web:
    build: .
    volumes:
      - .:/app
    ports:
      - "$server_port:8080"
    depends_on:
      - db
EOF
    echo "$composeFile" > docker-compose.yml
  fi
  if [ "$1" == no-file-rebuild ] || [ -z $1 ]
  then
    mavenCleanInstall
  fi
  if [ "$1" != no-rebuild ] 
  then
    mavenPack
    docker-compose up --build
  else
    docker-compose up
  fi
}
# Help message with tips
showHelp()
{
  echo Usage: bash madock.sh \<option\> \<folder_path\> \[port_to forward_for_tomcat\] \[port_to_forward_for postgres\]
}
# Maven cleaning, installing & packaging without maven itself!
mavenCleanInstall()
{
docker run -it --rm -v "$PWD":/app -w /app maven:3.3-jdk-8 mvn clean
docker run -it --rm -v "$PWD":/app -w /app maven:3.3-jdk-8 mvn install
}
mavenPack()
{
docker run -it --rm -v "$PWD":/app -w /app maven:3.3-jdk-8 mvn package
}
# Docker run commands
dockerRun()
{
docker run -p $server_port:8080 $app_name
}
# Mainflow
echo MaDock processing...
if [ ! -d $2 ]
then
  echo ERROR: You have to specify project folder
  showHelp
else
  cd $2
  app_name=${PWD##*/}
  [[ -z $3 ]] && server_port=8080 || server_port=$3
  [[ -z $4 ]] && db_port=5432 || db_port=$4
  case $1 in
    -s | simple) simpleBasicDockerizing s;;
    -sNM | simpleNM) simpleBasicDockerizing s no-maven-ci;;
    -sNR | simpleNR) simpleBasicDockerizing s no-rebuild;;
    -b | basic) simpleBasicDockerizing b;;
    -bNM | basicNM) simpleBasicDockerizing b no-maven-ci;;
    -bNR | basicNR) simpleBasicDockerizing b no-rebuild;;
    -c | compose) composeDockerizing;; 
    -cNF | composeNF) composeDockerizing no-file-rebuild;;
    -cNM | composeNM) composeDockerizing no-maven-ci;;
    -cNR | composeNR) composeDockerizing no-rebuild;;
    *) showHelp
  esac
fi
echo Thanks for using MaDock!
