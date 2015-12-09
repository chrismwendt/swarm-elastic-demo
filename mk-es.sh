#!/bin/bash

. common.sh

eval $(docker-machine env --swarm swarm-1)

# put the elasticsearch image on each swarm node
for i in seq 1 $SWARM_NODES; do
  docker-machine scp Dockerfile swarm-$i:.
  docker-machine scp elasticsearch-srv-discovery.zip swarm-$i:.
  docker-machine ssh swarm-$i docker build -t $ELASTICSEARCH_IMAGE .
done

CONSUL_IP=$(docker-machine ip consul)

for ((node=1; node<=$ES_NODES; node++))
do
    docker run -d \
            --name "es-$node" \
            -P \
            --net="multihost" \
            --memory=$ES_MAXMEM \
            --memory-swappiness=0 \
            --restart=unless-stopped \
            $ELASTICSEARCH_IMAGE \
            /bin/bash -c "elasticsearch -Des.node.name=es-$node \
                          -Des.cluster.name=$CLUSTER_NAME \
                          -Des.network.host=0.0.0.0 \
                          -Des.index.number_of_shards=$AMOUNT_SHARDS \
                          -Des.index.number_of_replicas=$AMOUNT_REPLICAS \
                          -Des.discovery.zen.ping.multicast.enabled=false \
                          -Des.discovery.type=srv \
                          -Des.discovery.srv.query=elastic.service.consul \
                          -Des.discovery.srv.servers=${CONSUL_IP}:${CONSUL_PORT} \
                          -Des.discovery.srv.protocol=${SRV_PROTOCOL} \
                          -Des.logger.discovery=TRACE"

    # may you've to change here the interface from eth0 to eth1 on boot2docker
    ES_IP=$(docker exec es-${node} ip addr | awk '/inet/ && /eth0/{sub(/\/.*$/,"",$2); print $2}')
    echo "IP of es-${node} is ${ES_IP}"

    EXT_IP=$(docker inspect --format='{{.Node.IP}}' es-$node)
    EXT_PORT=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "9300/tcp") 0).HostPort}}' es-$node)
    until nc -z $EXT_IP $EXT_PORT; do
        echo "Sleeping for 1s since node es-$node hasn't bound port 9300 yet"
        sleep 1
    done
    
    echo "Registering node in Consul"
    curl -X PUT \
      -d "{\"Node\": \"es-${node}\", \"Address\": \"${ES_IP}\", \"Service\": {\"ID\": \"elastic-${node}\", \"Service\": \"elastic\", \"ServiceAddress\": \"${ES_IP}\", \"Port\": 9300}}" \
      http://${CONSUL_IP}:8500/v1/catalog/register
    echo ""
done
