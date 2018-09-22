#!/bin/sh

set -x

STARTDATE=$(date '+%Y-%m-%dT%H:%M:%S')
docker stop gitlab-master gitlab-runner
docker container rm gitlab-runner

docker container start gitlab-master

set +x
echo -n 'Waiting for instance '
while (`true`); do
	if docker logs gitlab-master --since ${STARTDATE} --tail 100 2>&1 | grep -oE 'listening on addr=127\.0\.0\.1:8080' >/dev/null; then
		echo -n ' READY'
		break
	fi
	sleep 1
	echo -n '.'
done
echo
set -x

docker run -t -i \
	-v /var/run/docker.sock:/var/run/docker.sock \
	--name gitlab-runner gitlab/gitlab-runner register \
	\
	--executor "docker" \
	--docker-image debian:stable \
	--url "http://172.17.0.2/" \
	--registration-token "eU9pNHed42Tam1MAQFP4" \
	--description "docker-builder" \
	--tag-list "builder,debian" \
	--run-untagged \
	--locked="false"
docker container start gitlab-runner
sleep 1
docker container exec -t -i gitlab-runner /entrypoint verify
docker container exec -t -i gitlab-runner /entrypoint start
