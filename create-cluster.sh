#!/bin/bash

# make bash strict 
set -euo pipefail

# variables declaration-------------------------
# see & edit "env-config.sh" to tune parameters
source ./env-config.sh
#-----------------------------------------------

WDIR=$PWD

# K3S
K3S_K8S_PORT=6443

function main() 
{
  # checks
  checkEnv

  # create node0
  createControlPlane
  
  # create node1, node2...
  createWorkerNodes

  # config all the dependencies needed for this exp.lab
  configDependencies
}

function checkEnv()
{
  # jq is needed
  if ! command -v jq  &> /dev/null 
  then
    printf "\nThe jq command could not be found. \nPlease install it.\n"
    exit 1
  fi
 
  # we could try to be clever analysing pseudo-NICs but...
  clear
  printf "\a\nIf you are running this cluster on your laptop and you are connected to a VPN it's almost guaranteed you'll have issues."
  printf "\a\n\nThis link might be useful in trying to sort out networking issues: https://multipass.run/docs/troubleshooting-networking-on-macos\n"
  printf "\a\n<Ctrl-C> to exit and switch off your VPN or anything that may effect Multipass bridge - or \n<return> to carry on the installation  "
  read ans
}

#--CONTROL PLANE----------------------------------------------------
# launch node0, the K8s control plane with Canoncial Multipass + k3s
# multipass launch --name node0  --cpus 1 --mem 1024M --disk 3G -vvvv --cloud-init cloud-config-server.yaml
function createControlPlane()
{
  K3S_NODE_NAME=node0

  printf "\nCreating VM"
  printf "\n^^^^^^^^^^^"
  printf "\nNode name:\t%s" $K3S_NODE_NAME
  printf "\nCPUs:\t\t%s" $CPUS
  printf "\nMemory:\t\t%s" $MEM
  printf "\nDisk:\t\t%s\n" $DISK
  multipass launch --name $K3S_NODE_NAME --cpus $CPUS --mem $MEM --disk $DISK -v --cloud-init cloud-config-server.yaml

  # workaround function for Multipass inconsistent behaviour
  #workaround
}


#--WORKER NODES--------------------------------
# launch Canonical Multipass worker nodes + k3s
function createWorkerNodes()
{
  # get node0 ip address to pass to the agents 
  # assuming here that there is only node0 (there should be); this needs to be improved with $ multipass info node0 | jq...
  IP_NODE0=$(multipass list --format json | jq --raw-output '.list[] | .ipv4[0]')
  K3S_URL="https://$IP_NODE0:$K3S_K8S_PORT"

  # get the token from node0
  K3S_TOKEN=$(multipass exec node0 sudo cat /var/lib/rancher/k3s/server/node-token)

  # launch worker nodes (aka agents) as node1, node2... 
  for (( idx=1; idx<=$WRK_NODES_NUM; idx++ ))
  do
    K3S_NODE_NAME="node"$idx

    printf "\nCreating VM"
    printf "\n^^^^^^^^^^^"
    printf "\nNode name:\t%s" $K3S_NODE_NAME
    printf "\nCPUs:\t\t%s" $CPUS
    printf "\nMemory:\t\t%s" $MEM
    printf "\nDisk:\t\t%s" $DISK
    printf "\nNode0 URL:\t%s" $K3S_URL
    printf "\nToken:\t%s\n" $K3S_TOKEN
    multipass launch --name $K3S_NODE_NAME --cpus $CPUS --mem $MEM --disk $DISK -v --cloud-init cloud-config-agent.yaml

    # workaround function for Multipass inconsistent behaviour
    #workaround

    printf "\n\nInstalling k3s...\n"
    multipass exec $K3S_NODE_NAME -- /bin/bash -c "curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" K3S_NODE_NAME=${K3S_NODE_NAME} K3S_URL=${K3S_URL} K3S_TOKEN=${K3S_TOKEN} sh -"
    
    # allowing for agents to connect...
    sleep 20

    printf "\n\nConfiguring Kubernetes worker node..."
    # adding worker role
    printf "\nAdding worker role\n"
    multipass exec node0 -- /bin/bash -c "kubectl label node $K3S_NODE_NAME node-role.kubernetes.io/worker-$K3S_NODE_NAME=worker"
    
    # adding label for nodeSelector
    printf "\nLabeling node as a worker node\n"
    multipass exec node0 -- /bin/bash -c "kubectl label nodes $K3S_NODE_NAME worker=yes"

  done
}


# config the K8s cluster
#
function configDependencies()
{
  printf "\n\nInstalling Longhorn... \n"
  multipass exec node0 -- /bin/bash -c "kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.2.3/deploy/longhorn.yaml"

  printf "\n\nCopying resources...\n"
  if [ -d "./resources" ]
  then
    # yes we could optimize it...
    multipass exec node0 -- /bin/bash -c "mkdir /home/ubuntu/resources"

    # Dir 05
    cd "$WDIR"/resources
    multipass transfer files.tar.gz node0:/home/ubuntu/resources/files.tar.gz
    multipass exec node0 -- /bin/bash -c "cd /home/ubuntu/resources/ && tar zxvf files.tar.gz"
    
  else
    printf "\nFiles directory NOT present. Skipping copying of files."
  fi
}

# workaround for bug for moving the VM from Starting to Running
# See https://github.com/canonical/multipass/issues/2213
#
function workaround()
{
  GREEN="\033[0;32m"
  RED="\033[0;31m"
  # bold high intensity
  BIYellow='\033[1;93m'
  NC="\033[0m"
  printf "\a\n\n===========================================================================\n"
  #printf "\a\n${RED}******** ${NC} AT THE NEXT ${GREEN} ubuntu@node0:~$ ${NC} PROMPT, PLEASE TYPE ${BIYellow}exit ${RED}**********${NC}"
   printf "\a\n${RED}******** ${NC} AT THE NEXT ${GREEN} ubuntu@%s:~$ ${NC} PROMPT, PLEASE TYPE ${BIYellow}exit ${RED}**********${NC}" $K3S_NODE_NAME
  printf "\a\n============================================================================\n\n"
  sleep 5 
  multipass shell $K3S_NODE_NAME 
}


main
printf "\n\nAll done\n"
# --
