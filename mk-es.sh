#!/bin/bash

. common.sh

eval $(docker-machine env --swarm swarm-0)

# put the elasticsearch image on each swarm node
for i in $(seq 1 $SWARM_NODES); do
    docker-machine scp Dockerfile swarm-$i:.
    docker-machine scp elasticsearch-srv-discovery.zip swarm-$i:.
    docker-machine ssh swarm-$i docker build -t $ELASTICSEARCH_IMAGE .
done

CONSUL_IP=$(docker-machine ip consul)

for i in $(seq 1 $ES_NODES); do
    docker run -d \
        --name "es-$i" \
        -P \
        --net="multihost" \
        --memory=$ES_MAXMEM \
        --memory-swappiness=0 \
        --restart=unless-stopped \
        $ELASTICSEARCH_IMAGE \
        /bin/bash -c "\
            elasticsearch \
            -Des.node.name=es-$i \
            -Des.network.host=0.0.0.0 \
            -Des.discovery.zen.ping.multicast.enabled=false \
            -Des.discovery.type=srv \
            -Des.discovery.srv.query=elastic.service.consul \
            -Des.discovery.srv.servers=${CONSUL_IP}:${CONSUL_PORT} \
            -Des.discovery.srv.protocol=${SRV_PROTOCOL} \
            -Des.logger.discovery=TRACE"

    ES_IP=$(docker exec es-$i ip addr | awk '/inet/ && /eth0/{sub(/\/.*$/,"",$2); print $2}')
    EXT_IP=$(docker inspect --format='{{.Node.IP}}' es-$i)
    EXT_PORT=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "9300/tcp") 0).HostPort}}' es-$i)

    until nc -z $EXT_IP $EXT_PORT; do
        echo "Sleeping for 1s since node es-$i hasn't bound port 9300 yet"
        sleep 1
    done

    curl -X PUT \
      -d "{\"Node\": \"es-$i\", \"Address\": \"${ES_IP}\", \"Service\": {\"ID\": \"elastic-$i\", \"Service\": \"elastic\", \"ServiceAddress\": \"${ES_IP}\", \"Port\": 9300}}" \
      http://${CONSUL_IP}:8500/v1/catalog/register
done
