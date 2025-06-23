#!/bin/bash
set -e

docker ps -a --filter "ancestor=Xfce-250620" --format "{{.ID}}" | xargs -r docker rm -f

docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep Xfce-250620 | awk '{print $2}' | xargs -r docker rmi -f

rm -rf out/