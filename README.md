<!-- markdownlint-disable MD033 -->
# Using OpenSSL CA as Root CA in Hyperledger Fabric

<img src="img/hf-scenario.png" width="500" />

## Prerequisites

### Docker + Docker-Compose

Ensure that `docker` and `docker-compose` are installed.

### HF Binaries

Download binaries for Hyperledger Fabric v1.4.6

```bash
curl -sSL http://bit.ly/2ysbOFE | bash -s -- 1.4.6 -d -s
rm -f config/configtx.yaml config/core.yaml config/orderer.yaml
```

## Tutorial

Clone the repository which contains all the scripts and files needed for this demo. All commands are to be executed in the root folder of the repository.

```bash
git clone https://github.com/aldredb/external-ca
cd external-ca
```

Generate crypto-materials for **Orderer**

```bash
export PATH=$PWD/bin:$PATH
cryptogen generate --config=./crypto-config.yaml
```

Create the folder structure to store certs and keys of the peer organisation: `org1.example.com`. As seen below, There is going to be one peer, `peer0.org1.example.com` and three users, `admin`, `tlsadmin` and `Admin@org1.example.com`. The intermediate CA’s certificate and key will be stored in `ca` and `tlsca` folders.

```bash
ORG_DIR=$PWD/crypto-config/peerOrganizations/org1.example.com
PEER_DIR=$ORG_DIR/peers/peer0.org1.example.com
IDENTITY_REGISTRAR_DIR=$ORG_DIR/users/admin
TLS_REGISTRAR_DIR=$ORG_DIR/users/tlsadmin
ADMIN_DIR=$ORG_DIR/users/Admin@org1.example.com
mkdir -p $ORG_DIR/ca $ORG_DIR/tlsca $ORG_DIR/msp $PEER_DIR $IDENTITY_REGISTRAR_DIR $TLS_REGISTRAR_DIR $ADMIN_DIR
```

### Create Root Certificate Authorities

Create folder structure for **Identity Root CA**

```bash
mkdir -p identity-rca/private identity-rca/certs identity-rca/newcerts identity-rca/crl
touch identity-rca/index.txt identity-rca/serial
echo 1000 > identity-rca/serial
echo 1000 > identity-rca/crlnumber
```

Generate the Identity Root CA's private key. cryptogen and default Fabric CA settings uses ECDSA with curve prime256v1, so we are going to follow that standard. I have not experimented with other combination of algorithm and key sizes.

```bash
openssl ecparam -name prime256v1 -genkey -noout -out identity-rca/private/rca.identity.org1.example.com.key
```

Based on the private key, generate a Certificate Signing Request (CSR) and self-sign the CSR, producing the Identity Root certificate. Note that we use v3_ca extension. Root certificates are supposed to have long validity period, thus we set the period to 10 years.

```bash
openssl req -config openssl_root-identity.cnf -new -x509 -sha256 -extensions v3_ca -key identity-rca/private/rca.identity.org1.example.com.key -out identity-rca/certs/rca.identity.org1.example.com.cert -days 3650 -subj "/C=SG/ST=Singapore/L=Singapore/O=org1.example.com/OU=/CN=rca.identity.org1.example.com"
```

In a similar fashion, create the **TLS Root CA** folder structure and generate the certificate and key pairs

```bash
mkdir -p tls-rca/private tls-rca/certs tls-rca/newcerts tls-rca/crl
touch tls-rca/index.txt tls-rca/serial
echo 1000 > tls-rca/serial
echo 1000 > tls-rca/crlnumber

openssl ecparam -name prime256v1 -genkey -noout -out tls-rca/private/rca.tls.org1.example.com.key
openssl req -config openssl_root-tls.cnf -new -x509 -sha256 -extensions v3_ca -key tls-rca/private/rca.tls.org1.example.com.key -out tls-rca/certs/rca.tls.org1.example.com.cert -days 3650 -subj "/C=SG/ST=Singapore/L=Singapore/O=org1.example.com/OU=/CN=rca.tls.org1.example.com"
```

### Create Intermediate Certificate Authorities

Generate private key and CSR for **Identity Intermediate CA**. Note that the value of Organization (O) i.e. **org1.example.com** is the same as that of the **Identity Root CA**

```bash
openssl ecparam -name prime256v1 -genkey -noout -out $ORG_DIR/ca/ica.identity.org1.example.com.key

openssl req -new -sha256 -key $ORG_DIR/ca/ica.identity.org1.example.com.key -out $ORG_DIR/ca/ica.identity.org1.example.com.csr -subj "/C=SG/ST=Singapore/L=Singapore/O=org1.example.com/OU=/CN=ica.identity.org1.example.com"
```

The Identity Root CA signs the Identity Intermediate CA's CSR, issuing the certificate. The validity period is half that of the Root certificate. Note that we use `v3_intermediate_ca` extension.

```bash
openssl ca -batch -config openssl_root-identity.cnf -extensions v3_intermediate_ca -days 1825 -notext -md sha256 -in $ORG_DIR/ca/ica.identity.org1.example.com.csr -out $ORG_DIR/ca/ica.identity.org1.example.com.cert
```

Once we issue the identity intermediate CA's certificate, the Identity Root CA is not required anymore, unless there is a need to create another Intermediate CA or to revoke an Intermediate CA's certificate.
Create the "chain" file, which consists of both the Identity Intermediate CA's and Identity Root CA's certificate.

```bash
cat $ORG_DIR/ca/ica.identity.org1.example.com.cert $PWD/identity-rca/certs/rca.identity.org1.example.com.cert > $ORG_DIR/ca/chain.identity.org1.example.com.cert
```

In a similar fashion, generate the certificate and key pairs for **Intermediate TLS CA**

```bash
openssl ecparam -name prime256v1 -genkey -noout -out $ORG_DIR/tlsca/ica.tls.org1.example.com.key

openssl req -new -sha256 -key $ORG_DIR/tlsca/ica.tls.org1.example.com.key -out $ORG_DIR/tlsca/ica.tls.org1.example.com.csr -subj "/C=SG/ST=Singapore/L=Singapore/O=org1.example.com/OU=/CN=ica.tls.org1.example.com"

openssl ca -batch -config openssl_root-tls.cnf -extensions v3_intermediate_ca -days 1825 -notext -md sha256 -in $ORG_DIR/tlsca/ica.tls.org1.example.com.csr -out $ORG_DIR/tlsca/ica.tls.org1.example.com.cert

cat $ORG_DIR/tlsca/ica.tls.org1.example.com.cert $PWD/tls-rca/certs/rca.tls.org1.example.com.cert > $ORG_DIR/tlsca/chain.tls.org1.example.com.cert
```

Finally, start the Intermediate CA. The configuration file of Intermediate CA will point to the certificate, key and chain which we generated in the previous steps. Refer to `ca-config/fabric-ca-server-config.yaml` for the Identity CA instance and `ca-config/tlsca/fabric-ca-server-config.yaml` for the TLS CA instance

```bash
docker-compose up -d ica.org1.example.com
```

Once the container is up and running, confirm that there are `ca` and `tlsca` instances running in the container

```bash
curl http://localhost:7054/cainfo\?ca\=ca
curl http://localhost:7054/cainfo\?ca\=tlsca
```

Register and enroll users and peers for **Org1**, Wait at least 60 seconds before issuing the rest of the commands below. This is a safety measure to ensure that `NotBefore` property of the issued certificates are not earlier the `NotBefore` property of the Intermediate CA Certificate

As the Intermediate CA is ready, we can now create and sign user and peer certificates.

Enroll the `ca` registrar user, **admin**. The registrar user has the privilege to register other users. Notice the parameter `--caname ca`, which signifies interaction with the `ca` instance of the CA containers instead of `tlsca`

```bash
export FABRIC_CA_CLIENT_HOME=$IDENTITY_REGISTRAR_DIR
fabric-ca-client enroll --caname ca --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -m admin -u http://admin:adminpw@localhost:7054
```

**admin** registers user **Admin@org1.example.com**, who is going to be the **org1.example.com**'s admin, and peer **peer0.org1.example.com**

```bash
fabric-ca-client register --caname ca --id.name Admin@org1.example.com --id.secret mysecret --id.type client --id.affiliation org1 -u http://localhost:7054
fabric-ca-client register --caname ca --id.name peer0.org1.example.com --id.secret mysecret --id.type peer --id.affiliation org1 -u http://localhost:7054
```

Enroll **Admin@org1.example.com**

```bash
export FABRIC_CA_CLIENT_HOME=$ADMIN_DIR
fabric-ca-client enroll --caname ca --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -m Admin@org1.example.com -u http://Admin@org1.example.com:mysecret@localhost:7054
mkdir -p $ADMIN_DIR/msp/admincerts && cp $ADMIN_DIR/msp/signcerts/*.pem $ADMIN_DIR/msp/admincerts/
```

Enroll **peer0.org1.example.com**

```bash
export FABRIC_CA_CLIENT_HOME=$PEER_DIR
fabric-ca-client enroll --caname ca --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -m peer0.org1.example.com -u http://peer0.org1.example.com:mysecret@localhost:7054
mkdir -p $PEER_DIR/msp/admincerts && cp $ADMIN_DIR/msp/signcerts/*.pem $PEER_DIR/msp/admincerts/
```

Generate TLS certificate and key pair for **peer0.org1.example.com** to establish TLS sessions with other components. There is no need to generate TLS certificate and key pair for **Admin@org1.example.com** as a user does not use any TLS communication. Notice that the parameter `--caname` is set to `tlsca`

```bash
export FABRIC_CA_CLIENT_HOME=$TLS_REGISTRAR_DIR
fabric-ca-client enroll --caname tlsca --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -m admin -u http://admin:adminpw@localhost:7054

fabric-ca-client register --caname tlsca --id.name peer0.org1.example.com --id.secret mysecret --id.type peer --id.affiliation org1 -u http://localhost:7054

export FABRIC_CA_CLIENT_HOME=$PEER_DIR/tls
fabric-ca-client enroll --caname tlsca --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -m peer0.org1.example.com -u http://peer0.org1.example.com:mysecret@localhost:7054
cp $PEER_DIR/tls/msp/signcerts/*.pem $PEER_DIR/tls/server.crt
cp $PEER_DIR/tls/msp/keystore/* $PEER_DIR/tls/server.key
cat $PEER_DIR/tls/msp/intermediatecerts/*.pem $PEER_DIR/tls/msp/cacerts/*.pem > $PEER_DIR/tls/ca.crt
rm -rf $PEER_DIR/tls/msp $PEER_DIR/tls/*.yaml
```

At this point, we have successfully demonstrated that it is possible to combine 3rd party CAs and Fabric CA to form certificate chain of trust

<img src="img/cert-chain.png" width="400" />

### Setting up the whole network

<img src="img/network.png" width="500" />

Prepare **org1.example.com**'s MSP folder. We set **Admin@org1.example.com** as the admin of the organisation.

```bash
mkdir -p $ORG_DIR/msp/admincerts $ORG_DIR/msp/intermediatecerts $ORG_DIR/msp/cacerts $ORG_DIR/msp/tlscacerts $ORG_DIR/msp/tlsintermediatecerts
cp $ADMIN_DIR/msp/signcerts/*.pem $ORG_DIR/msp/admincerts/
cp $PEER_DIR/msp/cacerts/*.pem $ORG_DIR/msp/cacerts/
cp $PEER_DIR/msp/intermediatecerts/*.pem $ORG_DIR/msp/intermediatecerts/
cp $PWD/tls-rca/certs/rca.tls.org1.example.com.cert $ORG_DIR/msp/tlscacerts/
cp $ORG_DIR/tlsca/ica.tls.org1.example.com.cert $ORG_DIR/msp/tlsintermediatecerts/
```

Create Orderer Genesis Block and Channel Transaction

```bash
export FABRIC_CFG_PATH=${PWD}
configtxgen -profile OrdererGenesis -outputBlock ./config/genesis.block -channelID testchainid
configtxgen -profile Channel -outputCreateChannelTx ./config/channel1.tx -channelID channel1
```

Bring up **Orderer**, **Peer** and **CLI**

```bash
docker-compose up -d orderer.example.com peer0.org1.example.com cli
```

Create **channel1** and join **peer0.org1.example.com** to **channel1**. Note that the default user to perform all the operations from here onwards is **Admin@org1.example.com**, as specified in `CORE_PEER_MSPCONFIGPATH` environment variable in cli container.

```bash
docker exec cli peer channel create -o orderer.example.com:7050 --tls --cafile /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem -c channel1 -f /config/channel1.tx
docker exec cli peer channel join -b channel1.block
```

Install and instantiate chaincode

```bash
docker exec cli peer chaincode install -n chaincode1 -p github.com/chaincode1 -v 1
docker exec cli peer chaincode instantiate -o orderer.example.com:7050 --tls --cafile /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C channel1 -n chaincode1 -l "golang" -v 1 -c '{"Args":["init","a","81","b","11"]}' -P "OR('Org1MSP.member')"
```

Attempt to invoke and query chaincode

```bash
docker exec cli peer chaincode invoke -o orderer.example.com:7050 --tls --cafile /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C channel1 -n chaincode1 -c '{"Args":["put", "z", "7"]}' --waitForEvent
docker exec cli peer chaincode query -C channel1 -n chaincode1 -c '{"Args":["query","a"]}'
```

If querying chaincode succeeds, we have successfully used the certificates to interact with the Hyperledger Fabric network

## Creating Intermediate CA in IBM Blockchain Platform

Refer to [IBP.md](IBP.md)

## Destroy Network and Root CA

```bash
./destroy.sh
```
