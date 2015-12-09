#!/bin/bash

. common.sh

eval $(docker-machine env --swarm swarm-0)

CONSUL_IP=$(docker-machine ip consul)

for i in $(seq 1 $ES_NODES); do
    docker rm -f es-$i
    curl -X PUT -d "{\"Node\": \"es-${node}\"}" http://${CONSUL_IP}:8500/v1/catalog/deregister
done
wait

for i in $(seq 1 $SWARM_NODES); do
    docker-machine ssh swarm-$i docker rmi $ELASTICSEARCH_IMAGE &
done
wait
