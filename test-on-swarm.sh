#!/bin/bash

. common.sh

./rm-es.sh
./mk-es.sh
until [ $(curl -s $(./ipport.sh)/_nodes | jq ".nodes | length") = $ES_NODES ]; do
    echo "Waiting for $ES_NODES to form a cluster"
    sleep 1
done
