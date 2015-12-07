# A simple script to create a Docker Swarm Cluster with Docker Overlay Networking.
# Inspired by https://gist.github.com/tombee/7a6bb29219bddebb9602

DOCKER=/usr/local/bin/docker
DOCKER_MACHINE=/usr/local/bin/docker-machine

# If you want to use a specfic boot2docker image use this
BOOT2DOCKER_IMAGE="file:///mydirectory/my_own_boot2docker.iso"

# How many Swarm nodes (incl. Swarm master)?
AMMOUNT_NODES=4

# ... and this on VB, ammount is in MB
VB_DEFAULT_MEM=512

# If you wan't to install a Docker RC use this URL instead
# DOCKER_INSTALL_URL="https://test.docker.com"
DOCKER_INSTALL_URL="https://get.docker.com"

# You have to advertise the public interface of the VM
BIND_INTERFACE=eth1

# which Swarm version has to be installed?
# Check the Swarm releases page on Github ()
SWARM_IMAGE="swarm:1.0.0"

# use this with virtualbox if you use your own boot2docker image and comment out the next line
# DRIVER_SPECIFIC_VB="--driver virtualbox --virtualbox-boot2docker-url=$BOOT2DOCKER_IMAGE --virtualbox-memory=$VB_DEFAULT_MEM"
DRIVER_DEFINITION="--driver virtualbox --virtualbox-memory=$VB_DEFAULT_MEM"

# Consul DNS UDP Port
CONSUL_PORT_UDP=8600
#... and TCP 
CONSUL_PORT_TCP=8653

# create a node for consul, name it consul
echo "==> Create a node for consul..."
docker-machine create \
    $DRIVER_DEFINITION \
    --engine-install-url=$DOCKER_INSTALL_URL \
    consul || { echo 'Creation of Consul node failed' ; exit 1; }

echo "==> Installing and starting consul on that server"
$DOCKER $(docker-machine config consul) run \
                                       -d \
                                       -p 8500:8500 \
                                       -p 8400:8400 \
                                       -p ${CONSUL_PORT_UDP}:53/udp \
                                       -p ${CONSUL_PORT_TCP}:53/tcp \
                                       -h consul \
                                       progrium/consul -server -bootstrap-expect 1 -ui-dir /ui \
                                       || { echo 'Installation of Consul failed' ; exit 1; }

echo "==> Creating a node for swarm master and starting it..."
docker-machine create \
    $DRIVER_DEFINITION \
    --engine-install-url=$DOCKER_INSTALL_URL \
    --swarm \
    --swarm-image=$SWARM_IMAGE \
    --swarm-master \
    --swarm-discovery="consul://$(docker-machine ip consul):8500" \
    --engine-opt="cluster-advertise=$BIND_INTERFACE:2376" \
    --engine-opt="cluster-store=consul://$(docker-machine ip consul):8500" \
    swarm-1 || { echo 'Creation of Swarm Manager Node failed' ; exit 1; }

echo "==> Creating now all other nodes in parallel ..."
for ((node=2; node<=$AMMOUNT_NODES; node++))
do
    echo "Sending request to create node-$node now"
    $DOCKER_MACHINE create \
        $DRIVER_DEFINITION \
        --engine-install-url=$DOCKER_INSTALL_URL \
        --swarm \
        --swarm-image=$SWARM_IMAGE \
        --swarm-discovery="consul://$(docker-machine ip consul):8500" \
        --engine-opt="cluster-advertise=$BIND_INTERFACE:2376" \
        --engine-opt="cluster-store=consul://$(docker-machine ip consul):8500" \
        swarm-$node &
done

# wait until all nodes have been created
wait

echo "Creating overlay network"
eval $(docker-machine env --swarm swarm-1)
$DOCKER network create -d overlay multihost

echo "Access to Consul UI via http://$(docker-machine ip consul):8500/ui"

echo " **** Finished creating VMs and setting up Docker Swarm ****  "

