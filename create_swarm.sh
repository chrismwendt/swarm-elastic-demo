# How many Swarm nodes (incl. Swarm master)?
AMOUNT_NODES=4

# ... and this on VB, ammount is in MB
VB_DEFAULT_MEM=512

# You have to advertise the public interface of the VM
BIND_INTERFACE=eth1

# which Swarm version has to be installed?
# Check the Swarm releases page on Github ()
SWARM_IMAGE="swarm:1.0.0"

DRIVER_DEFINITION="--driver virtualbox --virtualbox-memory=$VB_DEFAULT_MEM"

# Consul DNS UDP Port
CONSUL_PORT_UDP=8600
#... and TCP 
CONSUL_PORT_TCP=8653

# create a node for consul, name it consul
echo "==> Create a node for consul..."
docker-machine create \
    $DRIVER_DEFINITION \
    consul || { echo 'Creation of Consul node failed' ; exit 1; }

echo "==> Installing and starting consul on that server"
docker $(docker-machine config consul) run \
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
    --swarm \
    --swarm-image=$SWARM_IMAGE \
    --swarm-master \
    --swarm-discovery="consul://$(docker-machine ip consul):8500" \
    --engine-opt="cluster-advertise=$BIND_INTERFACE:2376" \
    --engine-opt="cluster-store=consul://$(docker-machine ip consul):8500" \
    swarm-1 || { echo 'Creation of Swarm Manager Node failed' ; exit 1; }

echo "==> Creating now all other nodes in parallel ..."
for ((node=2; node<=$AMOUNT_NODES; node++))
do
    echo "Sending request to create node-$node now"
    docker-machine create \
        $DRIVER_DEFINITION \
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
docker network create -d overlay multihost
