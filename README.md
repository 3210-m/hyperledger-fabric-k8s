# Blockchain Solution with Hyperledger Fabric + Hyperledger Explorer on Kubernetes


**Maintainers:** [feitnomore](https://github.com/feitnomore/)

This is a simple guide to help you implement a complete Blockchain solution using [Hyperledger Fabric v1.3](https://hyperledger-fabric.readthedocs.io/en/release-1.3/whatsnew.html) with [Hyperledger Explorer v0.3.7](https://www.hyperledger.org/projects/explorer) on top of a [Kubernetes](https://kubernetes.io) platform.
This solution uses also [CouchDB](http://couchdb.apache.org/) as peer's backend, [Apache Kafka](https://kafka.apache.org/) topics for the orderers and a NFS Server *(Network file system)* to share data between the components.

*Note: Kafka/Zookeeper are running outside Kubernetes.*

*WARNING:* Use it at your own risk.

## BACKGROUND

A few weeks back, I've decided to take a look at Hyperledger Fabric solution to Blockchain, as it seems to be a technology that has been seeing an increase use and also is supported by giant tech companies like IBM and Oracle for example.
When I started looking at it, I've found lots of scripts like `start.sh`, `stop.sh`, `byfn.sh` and `eyfn.sh`. For me those seems like "magic", and everyone that I've talked to, stated that I should use those.
While using those scripts made me start fast, I had lots of trouble figuring out what was going on *behind the scenes* and also had a really hard time trying to customize the environment or run anything different from those samples.
At that point I've decided to start digging and started building a complete Blockchain environment, step-by-step, in order to see the details of how it works and how it can be achieved. This github repository is the result of my studies.

## INTRODUCTION

We're going to build a complete Hyperledger Fabric v1.3 environment with CA, Orderer and 4 Organizations. In order to achieve scalability and high availability on the Orderer we're going to be using Kafka. Each Organization will have 2 peers, and each peer will have it's own CouchDB instance. We're also going to deploy Hyperledger Explorer v0.3.7 with its PostgreSQL database as well.

## ARCHITECTURE

### Infrastructure view

For this environment we're going to be using a 3-node Kubernetes cluster, a 3-node Apache Zookeeper cluster (for Kafka), a 4-node Apache Kafka cluster and a NFS server. All the machines are going to be in the same network.

For Apache Zookeeper we'll have the following machines:
```sh
zk-0.zk-hs.fabric.svc.cluster.local
zk-1.zk-hs.fabric.svc.cluster.local
zk-2.zk-hs.fabric.svc.cluster.local
```
*Note: Zookeeper is needed by Apache Kafka.*
*Note: Apache Kafka should be 1.0 for Hyperledger compatibility.*
*Note: Check [this link](https://dzone.com/articles/how-to-setup-kafka-cluster) for a quick guide on Kafka/Zookeeper cluster.*
*Note: We're using 3 Zookeeper nodes as the minimum stated in [Hyperledger Fabric Kafka Documentation](https://hyperledger-fabric.readthedocs.io/en/release-1.3/kafka.html).*

For Apache Kafka we'll have the following machines:
```sh
kafka-0.kafka-svc.fabric.svc.cluster.local
kafka-1.kafka-svc.fabric.svc.cluster.local
kafka-2.kafka-svc.fabric.svc.cluster.local
```
*Note: We're using Kafka 1.0 version for Hyperledger compatibility.*
*Note: Check [this link](https://dzone.com/articles/how-to-setup-kafka-cluster) for a quick guide on Kafka/Zookeeper cluster.*
*Note: We're using 4 Kafka nodes as the minimum stated in [Hyperledger Fabric Kafka Documentation](https://hyperledger-fabric.readthedocs.io/en/release-1.3/kafka.html).*

For the NFS Server we'll have:

我们采用阿里云NAS解决方案

The image below represents the environment infrastructure:

![slide1.jpg](https://github.com/feitnomore/hyperledger-fabric-kubernetes/raw/master/images/slide1.jpg)


*Note: It's important to have all the environment with the time in sync as we're dealing with transactions and shared storage. Please make sure you have all the time in sync. I encourage you to use NTP on your servers. On my environment I have `ntpdate` running in a cron job.*
*Note: Kafka, Zookeeper and NFS Server are running outside Kubernetes.*

### Fabric Logical view

This environment will have a CA and a Orderer as Kubernetes deployments:
```sh
blockchain-ca
blockchain-orderer
```

We'll also have 4 organizations, with each organization having 2 peers, organized in the following deployments:
```sh
blockchain-org1peer1
blockchain-org1peer2
blockchain-org2peer1
blockchain-org2peer2
blockchain-org3peer1
blockchain-org3peer2
blockchain-org4peer1
blockchain-org4peer2
```

The image below represents this logical view:

![slide2.jpg](https://github.com/feitnomore/hyperledger-fabric-kubernetes/raw/master/images/slide2.jpg)

### Explorer Logical view
We're going to have Hyperledger Explorer as a WebUI for our environment. Hyperledger Explorer will run in 2 deployments as below:
```sh
blockchain-explorer-db
blockchain-explorer-app
```

The image below represents this logical view:

![slide3.jpg](https://github.com/feitnomore/hyperledger-fabric-kubernetes/raw/master/images/slide3.jpg)

### Detailed view
Hyperledger Fabric Orderer will connect itself to the Kafka servers as image below:

![slide4.jpg](https://github.com/feitnomore/hyperledger-fabric-kubernetes/raw/master/images/slide4.jpg)

Each Hyperledger Fabric Peer will have it's own CouchDB instance running as a sidecar and will connect to our NFS shared storage:

![slide5.jpg](https://github.com/feitnomore/hyperledger-fabric-kubernetes/raw/master/images/slide5.jpg)

*Note: Although its not depicted above, CA, Orderer and Explorer deployments will also have access to the NFS shared storage as they need the artifacts that we're going to store there.*

## IMPLEMENTATION

### Step 1: Checking environment

First let's make sure we have Kubernetes environment up & running:
```sh
kubectl get nodes
```

### Step 2: Setting up shared storage

在阿里云上根据NAS配置 PV 和 PVC

### Step 3: Launching a Fabric Tools helper pod

In order to perform some operations on the environment like file management, peer configuration and artifact generation, we'll need a helper `Pod` running `fabric-tools`.

```sh
kubectl apply -f kubernetes/fabric-tools.yaml
```

Make sure the `fabric-tools` `Pod` is running before we continue:
```sh
kubectl get pods
```

Now, assuming `fabric-tools` `Pod` is running, let's create a config directory on our shared filesystem to hold our files:
```sh
kubectl exec -it fabric-tools -n fabric -- mkdir /fabric/config
```

### Step 4: Loading the config files into the storage

1 - Configtx
Now we're going to create the file `config/configtx.yaml` with our network configuration.

Now let's copy the file we just created to our shared filesystem:
```sh
kubectl cp config/configtx.yaml fabric-tools:/fabric/config/ -n fabric
```

2 - Crypto-config
Now lets create the file `config/crypto-config.yaml` like below:

Let's copy the file to our shared filesystem:
```sh
kubectl cp config/crypto-config.yaml fabric-tools:/fabric/config/ -n fabric
```

3 - Chaincode
It's time to copy our example chaincode to the shared filesystem. In this case we'll be using balance-transfer example:
```sh
kubectl cp config/chaincode/ fabric-tools:/fabric/config/ -n fabric
```

### Step 5: Creating the necessary artifacts

1 - cryptogen
Time to generate our crypto material:
```sh
kubectl exec -it fabric-tools -n fabric -- /bin/bash
cryptogen generate --config /fabric/config/crypto-config.yaml
exit
```

Now we're going to copy our files to the correct path and rename the key files:
```sh
kubectl exec -it fabric-tools -n fabric -- /bin/bash
mv crypto-config /fabric/
for file in $(find /fabric/ -iname *_sk); do echo $file; dir=$(dirname $file); mv ${dir}/*_sk ${dir}/key.pem; done
exit
```


2 - configtxgen
Now we're going to copy the artifacts to the correct path and generate the genesis block:
```sh
kubectl exec -it fabric-tools -n fabric -- /bin/bash
cp /fabric/config/configtx.yaml /fabric/
cd /fabric
configtxgen -profile FourOrgsOrdererGenesis -outputBlock genesis.block
exit
```

3 - Anchor Peers
Lets create the Anchor Peers configuration files using configtxgen:
```sh
kubectl exec -it fabric-tools -n fabric -- /bin/bash
cd /fabric
configtxgen -profile FourOrgsChannel -outputAnchorPeersUpdate ./Org1MSPanchors.tx -channelID channel1 -asOrg Org1MSP
configtxgen -profile FourOrgsChannel -outputAnchorPeersUpdate ./Org2MSPanchors.tx -channelID channel1 -asOrg Org2MSP
configtxgen -profile FourOrgsChannel -outputAnchorPeersUpdate ./Org3MSPanchors.tx -channelID channel1 -asOrg Org3MSP
configtxgen -profile FourOrgsChannel -outputAnchorPeersUpdate ./Org4MSPanchors.tx -channelID channel1 -asOrg Org4MSP
exit
```
*Note: The generated files will be used later to update channel configuration with the respective Anchor Peers. This step is important for Hyperledger Fabric Service Discovery to work properly.*

4 - Fix Permissions
We need to fix the files permissions on our shared filesystem now:
```sh
kubectl exec -it fabric-tools -n fabric -- /bin/bash
chmod a+rx /fabric/* -R
exit
```


### Step 6: Setting up Fabric CA

```sh
kubectl apply -f kubernetes/blockchain-ca_deploy.yaml
```

```sh
kubectl apply -f kubernetes/blockchain-ca_svc.yaml
```


### Step 7: Setting up Fabric Orderer

```sh
kubectl apply -f kubernetes/blockchain-orderer_deploy.yaml
```

```sh
kubectl apply -f kubernetes/blockchain-orderer_svc.yaml
```

### Step 8: Org1MSP

创建 Peer 和 Peer Service

```sh
kubectl apply -f kubernetes/blockchain-org1peer1_deploy.yaml
kubectl apply -f kubernetes/blockchain-org1peer2_deploy.yaml
kubectl apply -f kubernetes/blockchain-org2peer1_deploy.yaml
kubectl apply -f kubernetes/blockchain-org2peer2_deploy.yaml
kubectl apply -f kubernetes/blockchain-org3peer1_deploy.yaml
kubectl apply -f kubernetes/blockchain-org3peer2_deploy.yaml
kubectl apply -f kubernetes/blockchain-org4peer1_deploy.yaml
kubectl apply -f kubernetes/blockchain-org4peer2_deploy.yaml


kubectl apply -f kubernetes/blockchain-org1peer1_svc.yaml
kubectl apply -f kubernetes/blockchain-org1peer2_svc.yaml
kubectl apply -f kubernetes/blockchain-org2peer1_svc.yaml
kubectl apply -f kubernetes/blockchain-org2peer2_svc.yaml
kubectl apply -f kubernetes/blockchain-org3peer1_svc.yaml
kubectl apply -f kubernetes/blockchain-org3peer2_svc.yaml
kubectl apply -f kubernetes/blockchain-org4peer1_svc.yaml
kubectl apply -f kubernetes/blockchain-org4peer2_svc.yaml
```


### Step 9: Create Channel
Now its time to create our channel:
```sh
kubectl exec -it fabric-tools -n fabric -- /bin/bash
export CHANNEL_NAME="channel1"
cd /fabric
configtxgen -profile FourOrgsChannel -outputCreateChannelTx ${CHANNEL_NAME}.tx -channelID ${CHANNEL_NAME}

export ORDERER_URL="blockchain-orderer:31010"
export CORE_PEER_ADDRESSAUTODETECT="false"
export CORE_PEER_NETWORKID="nid1"
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_MSPCONFIGPATH="/fabric/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp/"
export FABRIC_CFG_PATH="/etc/hyperledger/fabric"
peer channel create -o ${ORDERER_URL} -c ${CHANNEL_NAME} -f /fabric/${CHANNEL_NAME}.tx
exit
```

### Step 10: Join Channel

- Org1MSP
Let's join Org1MSP to our channel:
```sh
kubectl exec -it fabric-tools -n fabric -- /bin/bash
export CHANNEL_NAME="channel1"
export CORE_PEER_NETWORKID="nid1"
export ORDERER_URL="blockchain-orderer:31010"
export FABRIC_CFG_PATH="/etc/hyperledger/fabric"
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_MSPID="Org1MSP"
export CORE_PEER_MSPCONFIGPATH="/fabric/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp"

export CORE_PEER_ADDRESS="blockchain-org1peer1:30110"
peer channel fetch newest -o ${ORDERER_URL} -c ${CHANNEL_NAME}
peer channel join -b ${CHANNEL_NAME}_newest.block

rm -rf /${CHANNEL_NAME}_newest.block

export CORE_PEER_ADDRESS="blockchain-org1peer2:30110"
peer channel fetch newest -o ${ORDERER_URL} -c ${CHANNEL_NAME}
peer channel join -b ${CHANNEL_NAME}_newest.block

rm -rf /${CHANNEL_NAME}_newest.block
exit
```
- Org2MSP
Let's join Org2MSP to our channel:
```sh
kubectl exec -it fabric-tools -n fabric -- /bin/bash
export CHANNEL_NAME="channel1"
export CORE_PEER_NETWORKID="nid1"
export ORDERER_URL="blockchain-orderer:31010"
export FABRIC_CFG_PATH="/etc/hyperledger/fabric"
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_MSPID="Org2MSP"
export CORE_PEER_MSPCONFIGPATH="/fabric/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp"

export CORE_PEER_ADDRESS="blockchain-org2peer1:30110"
peer channel fetch newest -o ${ORDERER_URL} -c ${CHANNEL_NAME}
peer channel join -b ${CHANNEL_NAME}_newest.block

rm -rf /${CHANNEL_NAME}_newest.block

export CORE_PEER_ADDRESS="blockchain-org2peer2:30110"
peer channel fetch newest -o ${ORDERER_URL} -c ${CHANNEL_NAME}
peer channel join -b ${CHANNEL_NAME}_newest.block

rm -rf /${CHANNEL_NAME}_newest.block
exit
```
- Org3MSP
Let's join Org3MSP to our channel:
```sh
kubectl exec -it fabric-tools -n fabric -- /bin/bash
export CHANNEL_NAME="channel1"
export CORE_PEER_NETWORKID="nid1"
export ORDERER_URL="blockchain-orderer:31010"
export FABRIC_CFG_PATH="/etc/hyperledger/fabric"
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_MSPID="Org3MSP"
export CORE_PEER_MSPCONFIGPATH="/fabric/crypto-config/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp"

export CORE_PEER_ADDRESS="blockchain-org3peer1:30110"
peer channel fetch newest -o ${ORDERER_URL} -c ${CHANNEL_NAME}
peer channel join -b ${CHANNEL_NAME}_newest.block

rm -rf /${CHANNEL_NAME}_newest.block

export CORE_PEER_ADDRESS="blockchain-org3peer2:30110"
peer channel fetch newest -o ${ORDERER_URL} -c ${CHANNEL_NAME}
peer channel join -b ${CHANNEL_NAME}_newest.block

rm -rf /${CHANNEL_NAME}_newest.block
exit
```
- Org4MSP
Let's join Org4MSP to our channel:
```sh
kubectl exec -it fabric-tools -n fabric -- /bin/bash
export CHANNEL_NAME="channel1"
export CORE_PEER_NETWORKID="nid1"
export ORDERER_URL="blockchain-orderer:31010"
export FABRIC_CFG_PATH="/etc/hyperledger/fabric"
export CORE_PEER_LOCALMSPID="Org4MSP"
export CORE_PEER_MSPID="Org4MSP"
export CORE_PEER_MSPCONFIGPATH="/fabric/crypto-config/peerOrganizations/org4.example.com/users/Admin@org4.example.com/msp"

export CORE_PEER_ADDRESS="blockchain-org4peer1:30110"
peer channel fetch newest -o ${ORDERER_URL} -c ${CHANNEL_NAME}
peer channel join -b ${CHANNEL_NAME}_newest.block

rm -rf /${CHANNEL_NAME}_newest.block

export CORE_PEER_ADDRESS="blockchain-org4peer2:30110"
peer channel fetch newest -o ${ORDERER_URL} -c ${CHANNEL_NAME}
peer channel join -b ${CHANNEL_NAME}_newest.block

rm -rf /${CHANNEL_NAME}_newest.block
exit
```

### Step 11: Install Chaincode

- Org1MSP
Let's install our chaincode on Org1MSP Peers:
```sh
kubectl exec -it fabric-tools -n fabric -- /bin/bash
cp -r /fabric/config/chaincode $GOPATH/src/
export CHAINCODE_NAME="cc"
export CHAINCODE_VERSION="1.0"
export FABRIC_CFG_PATH="/etc/hyperledger/fabric"
export CORE_PEER_MSPCONFIGPATH="/fabric/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp"
export CORE_PEER_LOCALMSPID="Org1MSP"

export CORE_PEER_ADDRESS="blockchain-org1peer1:30110"
peer chaincode install -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} -p chaincode_example02/

export CORE_PEER_ADDRESS="blockchain-org1peer2:30110"
peer chaincode install -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} -p chaincode_example02/

exit
```
- Org2MSP
Let's install our chaincode on Org2MSP Peers:
```sh
kubectl exec -it fabric-tools -n fabric -- /bin/bash
cp -r /fabric/config/chaincode $GOPATH/src/
export CHAINCODE_NAME="cc"
export CHAINCODE_VERSION="1.0"
export FABRIC_CFG_PATH="/etc/hyperledger/fabric"
export CORE_PEER_MSPCONFIGPATH="/fabric/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp"
export CORE_PEER_LOCALMSPID="Org2MSP"

export CORE_PEER_ADDRESS="blockchain-org2peer1:30110"
peer chaincode install -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} -p chaincode_example02/

export CORE_PEER_ADDRESS="blockchain-org2peer2:30110"
peer chaincode install -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} -p chaincode_example02/

exit
```
- Org3MSP
Let's install our chaincode on Org3MSP Peers:
```sh
kubectl exec -it fabric-tools -n fabric -- /bin/bash
cp -r /fabric/config/chaincode $GOPATH/src/
export CHAINCODE_NAME="cc"
export CHAINCODE_VERSION="1.0"
export FABRIC_CFG_PATH="/etc/hyperledger/fabric"
export CORE_PEER_MSPCONFIGPATH="/fabric/crypto-config/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp"
export CORE_PEER_LOCALMSPID="Org3MSP"

export CORE_PEER_ADDRESS="blockchain-org3peer1:30110"
peer chaincode install -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} -p chaincode_example02/

export CORE_PEER_ADDRESS="blockchain-org3peer2:30110"
peer chaincode install -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} -p chaincode_example02/

exit
```
- Org4MSP
Let's install our chaincode on Org4MSP Peers:
```sh
kubectl exec -it fabric-tools -n fabric -- /bin/bash
cp -r /fabric/config/chaincode $GOPATH/src/
export CHAINCODE_NAME="cc"
export CHAINCODE_VERSION="1.0"
export FABRIC_CFG_PATH="/etc/hyperledger/fabric"
export CORE_PEER_MSPCONFIGPATH="/fabric/crypto-config/peerOrganizations/org4.example.com/users/Admin@org4.example.com/msp"
export CORE_PEER_LOCALMSPID="Org4MSP"

export CORE_PEER_ADDRESS="blockchain-org4peer1:30110"
peer chaincode install -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} -p chaincode_example02/

export CORE_PEER_ADDRESS="blockchain-org4peer2:30110"
peer chaincode install -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} -p chaincode_example02/

exit
```

### Step 12: Instantiate Chaincode

Now its time to instantiate our chaincode:
```sh
kubectl exec -it fabric-tools -n fabric -- /bin/bash
export CHANNEL_NAME="channel1"
export CHAINCODE_NAME="cc"
export CHAINCODE_VERSION="1.0"
export FABRIC_CFG_PATH="/etc/hyperledger/fabric"
export CORE_PEER_MSPCONFIGPATH="/fabric/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp"
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_ADDRESS="blockchain-org1peer1:30110"
export ORDERER_URL="blockchain-orderer:31010"

peer chaincode instantiate -o ${ORDERER_URL} -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} -P "AND('Org1MSP.member','Org2MSP.member','Org3MSP.member','Org4MSP.member')" -c '{"Args":["init","a","300","b","600"]}'
exit
```
*Note: The policy -P is set using AND. This will set the policy in a way that at least 1 peer from each Org will need to endorse the transaction.*
*Note: Because of this policy, every transaction sent to the network will have to be sent to at least 1 peer from each organization.*
*Note: As we're using Balance Transfer example, we're starting A with 300 and B with 600.*

### Step 13: AnchorPeers

Now we need to update our channel configuration to reflect our Anchor Peers:
```sh
pod=$(kubectl get pods -n fabric | grep blockchain-org1peer1 | awk '{print $1}')
kubectl exec -it $pod -n fabric -- peer channel update -f /fabric/Org1MSPanchors.tx -c channel1 -o blockchain-orderer:31010

pod=$(kubectl get pods -n fabric  | grep blockchain-org2peer1 | awk '{print $1}')
kubectl exec -it $pod -n fabric -- peer channel update -f /fabric/Org2MSPanchors.tx -c channel1 -o blockchain-orderer:31010

pod=$(kubectl get pods -n fabric | grep blockchain-org3peer1 | awk '{print $1}')
kubectl exec -it $pod -n fabric -- peer channel update -f /fabric/Org3MSPanchors.tx -c channel1 -o blockchain-orderer:31010

pod=$(kubectl get pods -n fabric | grep blockchain-org4peer1 | awk '{print $1}')
kubectl exec -it $pod -n fabric -- peer channel update -f /fabric/Org4MSPanchors.tx -c channel1 -o blockchain-orderer:31010
```
*Note: This step is very important for the Hyperledger Fabric Service Discovery to work properly.*
*Note: For each organization we only need to execute the peer channel update once.*
*Note: The command is executed on a peer that is on the same Organization as the Anchor file.*

### Step 14: Deploy Hyperledger Explorer

```sh
kubectl apply -f kubernetes/blockchain-explorer-db_deploy.yaml
```

```sh
kubectl apply -f kubernetes/blockchain-explorer-db_svc.yaml
```

Now, before proceeding, make sure the PostgreSQL Pod is running. We need to create the tables and artifacts for Hyperledger Explorer in our database:
```sh
pod=$(kubectl get pods -n fabric | grep blockchain-explorer-db | awk '{print $1}')
kubectl exec -it $pod -n fabric -- /bin/bash
mkdir -p /fabric/config/explorer/db/
mkdir -p /fabric/config/explorer/app/
cd /fabric/config/explorer/db/
wget https://raw.githubusercontent.com/hyperledger/blockchain-explorer/master/app/persistence/fabric/postgreSQL/db/createdb.sh
wget https://raw.githubusercontent.com/hyperledger/blockchain-explorer/master/app/persistence/fabric/postgreSQL/db/explorerpg.sql
wget https://raw.githubusercontent.com/hyperledger/blockchain-explorer/master/app/persistence/fabric/postgreSQL/db/processenv.js
wget https://raw.githubusercontent.com/hyperledger/blockchain-explorer/master/app/persistence/fabric/postgreSQL/db/updatepg.sql
apk update
apk add jq
apk add nodejs
apk add sudo
rm -rf /var/cache/apk/*
chmod +x ./createdb.sh
./createdb.sh
exit
```
Now, we're going to create the config file with our Hyperledger Network description to use on Hyperledger Explorer. In order to do that, we'll create the file `config/explorer/app/config.json`

After creating the file, its time to copy it to our shared filesystem:
```sh
kubectl cp config/explorer/app/config.json fabric-tools:/fabric/config/explorer/app/ -n fabric
```

Create the `config/explorer/app/run.sh` as below:
```sh
#!/bin/sh
mkdir -p /opt/explorer/app/platform/fabric/
mkdir -p /tmp/

mv /opt/explorer/app/platform/fabric/config.json /opt/explorer/app/platform/fabric/config.json.vanilla
cp /fabric/config/explorer/app/config.json /opt/explorer/app/platform/fabric/config.json

cd /opt/explorer
node $EXPLORER_APP_PATH/main.js && tail -f /dev/null
```

After creating the file, its time to copy it to our shared filesystem:
```sh
chmod +x config/explorer/app/run.sh
kubectl cp config/explorer/app/run.sh fabric-tools:/fabric/config/explorer/app/ -n fabric
```

Now its time to create our Hyperledger Explorer application `Deployment` by creating the file `kubernetes/blockchain-explorer-app_deploy.yaml` as below:

Now its time to apply our `Deployment`:
```sh
kubectl apply -f kubernetes/blockchain-explorer-app_deploy.yaml
```

## CLEANUP

Now, to leave our environment clean, we're going to remove our helper `Pod`:
```sh
kubectl delete -f kubernetes/fabric-tools.yaml
```

## VALIDATING

Now, we're going to run 2 transactions. The first one we'll move 50 from `A` to `B`. The second one we'll move 33 from `B` to `A`:
```sh
pod=$(kubectl get pods -n fabric | grep blockchain-org1peer1 | awk '{print $1}')
kubectl exec -it $pod -n fabric -- /bin/bash

peer chaincode invoke --peerAddresses localhost:30110 --peerAddresses blockchain-org2peer1:30110 --peerAddresses blockchain-org3peer1:30110 --peerAddresses blockchain-org4peer1:30110 -o blockchain-orderer:31010 -C channel1 -n cc -c '{"Args":["invoke","a","b","50"]}'

peer chaincode invoke --peerAddresses localhost:30110 --peerAddresses blockchain-org2peer1:30110 --peerAddresses blockchain-org3peer1:30110 --peerAddresses blockchain-org4peer1:30110 -o blockchain-orderer:31010 -o blockchain-orderer:31010 -C channel1 -n cc -c '{"Args":["invoke","b","a","33"]}'

exit
```
*Note: The invoke command is using --peerAddresses parameter four times, in order to send the transaction to at least one peer from each organization.*
*Note: The first transaction might take a little bit to go through.*
*Note: We're executing transaction on Org1MSP Peer1.*

Now we're going to check our balance. As stated before, we've started `A` with 300 and `B` with 600:
```sh
pod=$(kubectl get pods -n fabric | grep blockchain-org1peer1 | awk '{print $1}')
kubectl exec -it $pod -n fabric -- /bin/bash

peer chaincode query --peerAddresses localhost:30110 -C channel1 -n cc -c '{"Args":["query","a"]}'

peer chaincode query --peerAddresses localhost:30110 -C channel1 -n cc -c '{"Args":["query","b"]}'

exit
```
*Note: A should return 283 and B should return 617.*
*Note: We're executing transaction on Org1MSP Peer1.*

We can also check the network status as well as the transactions on Hyperledger Explorer:
```sh
pod=$(kubectl get pods -n fabric | grep blockchain-explorer-app | awk '{print $1}')
kubectl port-forward $pod 8080:8080 -n fabric
```

Now open your browser to [http://127.0.0.1:8080/](http://127.0.0.1:8080/).
In the first window you can see your network status and transactions as below:

![slide6.jpg](https://github.com/feitnomore/hyperledger-fabric-kubernetes/raw/master/images/slide6.jpg)

You can also click on transactions tab, and check for a transaction as below:

![slide7.jpg](https://github.com/feitnomore/hyperledger-fabric-kubernetes/raw/master/images/slide7.jpg)

*Note: You can see here that the transaction got endorsed by all the 4 Organizations.*

## Reference Links

* [Hyperledger Fabric](https://hyperledger-fabric.readthedocs.io/en/release-1.3/)
* [Hyperledger Explorer](https://www.hyperledger.org/projects/explorer)
* [Apache CouchDB](http://couchdb.apache.org/)
* [Apache Kafka](https://kafka.apache.org/)
* [Kubernetes Concepts](https://kubernetes.io/docs/concepts/)
