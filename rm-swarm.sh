#!/bin/bash

. common.sh

docker-machine rm consul &

for i in seq 1 $SWARM_NODES; do
    docker-machine rm swarm-$i &
done
wait
