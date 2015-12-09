#!/bin/bash

. common.sh

[ $# -eq 1 ] || (echo "Usage: $0 <plugin-dir>" && exit 1)

PLUGIN_DIR=$1

cd $PLUGIN_DIR
gradle distZip
for var in $(gradle -q dump_versions); do
    export $var
done

cd - > /dev/null
cp $PLUGIN_DIR/build/distributions/elasticsearch-srv-discovery-$version.zip .

./rm-es.sh
./mk-es.sh
until [ $(curl -s $(./ip:port.sh es-1)/_nodes | jq ".nodes | length") = $ES_NODES ]; do
    echo "Waiting for $ES_NODES to form a cluster"
    sleep 1
done
