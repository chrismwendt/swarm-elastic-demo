#!/bin/bash

container=$1

echo $(docker inspect --format='{{.Node.IP}}' $container):$(docker inspect --format='{{(index (index .NetworkSettings.Ports "9200/tcp") 0).HostPort}}' $container)
