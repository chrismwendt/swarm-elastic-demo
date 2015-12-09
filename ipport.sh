#!/bin/bash

echo $(docker inspect --format='{{.Node.IP}}' es-1):$(docker inspect --format='{{(index (index .NetworkSettings.Ports "9200/tcp") 0).HostPort}}' es-1)
