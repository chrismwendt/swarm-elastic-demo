#!/bin/bash

. common.sh

docker-machine create $DRIVER_DEFINITION consul

docker $(docker-machine config consul) run \
    -d \
    -p 8500:8500 \
    -p 8400:8400 \
    -p ${CONSUL_PORT_UDP}:53/udp \
    -p ${CONSUL_PORT_TCP}:53/tcp \
    -h consul \
    progrium/consul -server -bootstrap-expect 1 -ui-dir /ui

SWARM_OPTIONS="\
    --swarm \
    --swarm-image=$SWARM_IMAGE \
    --swarm-discovery='consul://$(docker-machine ip consul):8500' \
    --engine-opt='cluster-advertise=$BIND_INTERFACE:2376' \
    --engine-opt='cluster-store=consul://$(docker-machine ip consul):8500'"

docker-machine create $DRIVER_DEFINITION $SWARM_OPTIONS --swarm-master swarm-1

for i in $(seq 1 $SWARM_NODES); do
    docker-machine create $DRIVER_DEFINITION $SWARM_OPTIONS swarm-$i &
done
wait

eval $(docker-machine env --swarm swarm-1)
docker network create -d overlay multihost
