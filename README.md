# LocalK8s

This is a local (think laptop) solution for running a meanigful tiny K8s cluster.
It is as lightweight as 2 Linux VMs can be. It is preferable to have 3 workers nodes, its default.
The inspiration came for learning K8s without having to provision it in the cloud and also because of the need for a training course.

## Solution Components
Solution like minikube and KIND are cute but don't allow you to test and check K8s behavior over multiple nodes, nor can you play with distributed storage.
Bottom line we need a multi-node solution that supports iSCSI for block storage  - FYI [DiD](https://github.com/jpetazzo/dind) was investigated but it misses Linux node fundamentals so the question is then: what is a lightweight (like containers ??) VM hypervisor that allows us to quickly run a K8s cluster?
Canonical Multipass tries its best. The default Ubuntu images, that Multipass uses, are fairly light and its CLI UX is very intuitive and fast.

The components have been selected for their "lightweightness" and the only three requirements are:
- [Multipass](https://multipass.run/)
- [jq](https://stedolan.github.io/jq/download/) and
- an internet connection (be warned, VPNs can cause havoc)

The components installed for you are:
1. [K3s](https://k3s.io/) - the lightweight K8s implementation by Rancher
2. [Longhorn](https://longhorn.io/) - the open source distributed block storage with a CSI driver for K8s
	- if you are interested in more CSI-supporting block-storage solutions for K8s see [this K8s storage list](https://github.com/zrml/k8s-csi-storage-drivers)
3. some files to get started with IRIS

## How to create the local K8s cluster
To create the local K8s cluster simply run  
```./create-cluster.sh```  


You can configure the numbers of K8s **worker nodes** and the **VMs sizing** by editing the environment variables in  
```env-config.sh```  

By default the script creates 3 worker nodes. That is necessary if you want to test Longhorn as it requires 3 nodes for resiliency.
All together you'd be running 4 VMs:
- node0 - the main K8s cluster API and your main working node where you can issue all your *kubectl* commands
- node1 - the first worker node
- node2 - the second worker node
- node3 - the third worker node

which means that with the default parameters you'll probably need 16GB of memory and a good multicore processor. Avoid having other heavy tasks running like Docker Desktop etc.
The cluster creation will take several minutes. On my M1 it's about 5 min. Consider that it pulls VM images, K3s, kubectl, Longhorn and it installs it all.

If three worker nodes are too many for your hardware consider reviewing the `env-config.sh` file.
I have found that the VM sizing is the most compact that would allow me to run the cluster and several extra containers like InterSystems IRIS. Anything smaller than that and I had issues. 
While the number of worker nodes, expressed in the environment variable `WRK_NODES_NUM=3`, can be tuned down to 1, Longhorn might not behave as expected if there aren't 3 nodes available. Of course, with a single worker node any K8s exercise related to maintaining a workload state despite failure will most probably fail as well.

## Multipass commands
After you have created the cluster you can check that all the nodes are running with 
```
$ multipass list
Name                    State             IPv4             Image
node0                   Running           192.168.64.6     Ubuntu 20.04 LTS
                                          10.42.0.0
                                          10.42.0.1
node1                   Running           192.168.64.7     Ubuntu 20.04 LTS
                                          10.42.1.0
                                          10.42.1.1
node2                   Running           192.168.64.8     Ubuntu 20.04 LTS
                                          10.42.2.0
                                          10.42.2.1
node3                   Running           192.168.64.9     Ubuntu 20.04 LTS
                                          10.42.3.0
                                          10.42.3.1
```  

To use the K8s cluster simply jump into `node0` that has the *kubectl* client already setup for you. 
```
multipass shell node0
```    

At the Linux prompt you can use any _kubectl_ you like 
```
kubectl get nodes -owide
```  
and  
```
kubectl get pod -A -owide
```    
etc.  

Once you are done with your local K8s cluster you have options to
- Stop it and restart it when needed 
  - `multipass stop --all`  

- Stop it and delete it which deletes the VM images
  - `multipass stop --all`  
  - `multipass delete --all`  

- Stop, delete and remove it all from your laptop
  - `multipass stop --all`  
  - `multipass delete --all`  
  - `multipass purge`  


again keep checking what Multipass has to say about your VMs with `multipass list` 


## Extras
In *node0*, under $HOME you will find a `resources`  sub-directory.
It contains some YAML K8s files declaration that we can use to run IRIS.

