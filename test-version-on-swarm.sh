#!/bin/bash

[ $# -eq 1 ] || (echo "Usage: $0 <plugin-dir>" && exit 1)

PLUGIN_DIR=$1

cd $PLUGIN_DIR
gradle distZip
for var in $(gradle -q dump_versions); do
    export $var
done

cd - > /dev/null
cp $PLUGIN_DIR/build/distributions/elasticsearch-srv-discovery-$version.zip .
./test-on-swarm.sh
