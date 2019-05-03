# Using OpenSSL CA as Root CA in Hyperledger Fabric

Execute all commands in the folder root

## Prerequisites

### Docker + Docker-Compose

Ensure that `docker` and `docker-compose` are installed.

### HF Binaries

Download binaries for Hyperledger Fabric v1.4.1

```bash
curl -sSL http://bit.ly/2ysbOFE | bash -s -- 1.4.1 -d -s
rm -f config/configtx.yaml config/core.yaml config/orderer.yaml
```

## Deployment

Generate crypto-materials for **Orderer**

```bash
export PATH=$PWD/bin:$PATH
export FABRIC_CFG_PATH=${PWD}
cryptogen generate --config=./crypto-config.yaml
```

Create folder structure for **Org1**'s crypto-materials

```bash
ORG_DIR=$PWD/crypto-config/peerOrganizations/org1.example.com
PEER_DIR=$ORG_DIR/peers/peer0.org1.example.com
REGISTRAR_DIR=$ORG_DIR/users/admin
ADMIN_DIR=$ORG_DIR/users/Admin@org1.example.com
mkdir -p $ORG_DIR/ca $ORG_DIR/msp $PEER_DIR $REGISTRAR_DIR $ADMIN_DIR
```

Create **Root CA**

```bash
mkdir -p rca/private rca/certs rca/newcerts
touch rca/index.txt rca/serial
echo 1000 > rca/serial
openssl ecparam -name prime256v1 -genkey -noout -out rca/private/rca.org1.example.com.key.pem
openssl req -config openssl_root.cnf -new -x509 -sha256 -extensions v3_ca -key rca/private/rca.org1.example.com.key.pem -out rca/certs/rca.org1.example.com.crt.pem -days 3650 -subj "/C=SG/ST=Singapore/L=Singapore/O=org1.example.com/OU=/CN=rca.org1.example.com"
```

Generate key and cert for **Intermediate CA**

```bash
openssl ecparam -name prime256v1 -genkey -noout -out $ORG_DIR/ca/ica.org1.example.com.key.pem

openssl req -new -sha256 -key $ORG_DIR/ca/ica.org1.example.com.key.pem -out $ORG_DIR/ca/ica.org1.example.com.csr -subj "/C=SG/ST=Singapore/L=Singapore/O=org1.example.com/OU=/CN=ica.org1.example.com"

openssl ca -batch -config openssl_root.cnf -extensions v3_intermediate_ca -days 1825 -notext -md sha256 -in $ORG_DIR/ca/ica.org1.example.com.csr -out $ORG_DIR/ca/ica.org1.example.com.crt.pem

cat $ORG_DIR/ca/ica.org1.example.com.crt.pem $PWD/rca/certs/rca.org1.example.com.crt.pem > $ORG_DIR/ca/chain.org1.example.com.crt.pem
```

Bring up **Intermediate CA**

```bash
docker-compose up -d ica.org1.example.com
```

Register and enroll users and peers for **Org1**, Wait at least 30 seconds before issuing the rest of the commands below. This is a safety measure to ensure that `NotBefore` property of the issued certificates are not earlier the `NotBefore` property of the Intermediate CA Certificate

```bash
export FABRIC_CA_CLIENT_HOME=$REGISTRAR_DIR
fabric-ca-client enroll --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -m admin -u http://admin:adminpw@localhost:7054

fabric-ca-client register --id.name Admin@org1.example.com --id.secret mysecret --id.type client --id.affiliation org1 -u http://localhost:7054
fabric-ca-client register --id.name peer0.org1.example.com --id.secret mysecret --id.type peer --id.affiliation org1 -u http://localhost:7054

export FABRIC_CA_CLIENT_HOME=$ADMIN_DIR
fabric-ca-client enroll --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -m Admin@org1.example.com -u http://Admin@org1.example.com:mysecret@localhost:7054
mkdir -p $ADMIN_DIR/msp/admincerts && cp $ADMIN_DIR/msp/signcerts/*.pem $ADMIN_DIR/msp/admincerts/

export FABRIC_CA_CLIENT_HOME=$PEER_DIR
fabric-ca-client enroll --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -m peer0.org1.example.com -u http://peer0.org1.example.com:mysecret@localhost:7054
mkdir -p $PEER_DIR/msp/admincerts && cp $ADMIN_DIR/msp/signcerts/*.pem $PEER_DIR/msp/admincerts/
```

Prepare **Org1** MSP

```bash
mkdir -p $ORG_DIR/msp/admincerts $ORG_DIR/msp/intermediatecerts $ORG_DIR/msp/cacerts
cp $ADMIN_DIR/msp/signcerts/*.pem $ORG_DIR/msp/admincerts/
cp $PEER_DIR/msp/cacerts/*.pem $ORG_DIR/msp/cacerts/
cp $PEER_DIR/msp/intermediatecerts/*.pem $ORG_DIR/msp/intermediatecerts/
```

Create Orderer Genesis Block and Channel Transaction

```bash
configtxgen -profile OrdererGenesis -outputBlock ./config/genesis.block -channelID testchainid
configtxgen -profile Channel -outputCreateChannelTx ./config/channel1.tx -channelID channel1
```

Bring up **Orderer**, **Peer** and **CLI**

```bash
docker-compose up -d orderer.example.com peer0.org1.example.com cli
docker exec cli peer channel create -o orderer.example.com:7050 -c channel1 -f /config/channel1.tx
docker exec cli peer channel join -b channel1.block
```

Run chaincode

```bash
docker exec cli peer chaincode install -n chaincode1 -p github.com/chaincode1 -v 1
docker exec cli peer chaincode instantiate -o orderer.example.com:7050 -C channel1 -n chaincode1 -l "golang" -v 1 -c "{\"Args\":[\"init\",\"a\",\"81\",\"b\",\"11\"]}" -P "OR('Org1MSP.member')"
docker exec cli peer chaincode query -C channel1 -n chaincode1 -c '{"Args":["query","a"]}'
```

## Destroy Network and Root CA

```bash
./destroy.sh
```

## Command Dumps

```bash
docker exec cli configtxlator proto_decode --input /config/genesis.block --type common.Block --output /config/genesis.json
```