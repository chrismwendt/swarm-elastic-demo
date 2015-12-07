#! /usr/bin/env bash

# A small script to remove the es cluster containers 
# and to deregister them on consul

DOCKER=/usr/local/bin/docker
DOCKER_MACHINE=/usr/local/bin/docker-machine

AMOUNT_SWARM_NODES=4
AMOUNT_NODES=9

# set docker host coordinates correctly
eval $($DOCKER_MACHINE env --swarm swarm-1)

# getting consul IP
echo "Retrieving Consul IP..."
CONSUL_IP=$(docker-machine ip consul)
echo "Consul IP is $CONSUL_IP"

seq 1 $AMOUNT_SWARM_NODES | xargs -I {} -n 1 -P $AMOUNT_SWARM_NODES docker-machine ssh swarm-{} docker rmi elasticsearch-srv

$DOCKER rm -f es-1 es-2 es-3 es-4 es-5 es-6 es-7 es-8 es-9

for ((node=1; node<=$AMOUNT_NODES; node++))
do
    echo "Deregstering node es-${node}"
    # curl -X PUT \
    #   -d "{\"Node\": \"es-${node}\", \"ServiceID\": \"es-${node}\"}" \
    #   http://${CONSUL_IP}:8500/v1/catalog/deregister
    curl -X PUT \
      -d "{\"Node\": \"es-${node}\"}" \
      http://${CONSUL_IP}:8500/v1/catalog/deregister

    echo ""
done

echo "Finished."
