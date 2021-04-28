#!/bin/sh

export SUBJ="/C=TW/ST=Taiwan/O=org1.example.com/CN="
export CSR_NAMES="C=TW,ST=Taiwan,O=org1.example.com"
export CHANNEL_NAME="external-ca-channel"

export ORG_DIR=$PWD/crypto-config/peerOrganizations/org1.example.com
export PEER_DIR=$ORG_DIR/peers/peer0.org1.example.com
export IDENTITY_REGISTRAR_DIR=$ORG_DIR/users/admin
export TLS_REGISTRAR_DIR=$ORG_DIR/users/tlsadmin
export ADMIN_DIR=$ORG_DIR/users/Admin@org1.example.com

sudo docker-compose up -d ica.org1.example.com

sleep 5
curl http://localhost:7054/cainfo\?ca\=ca
curl http://localhost:7054/cainfo\?ca\=tlsca

export FABRIC_CA_CLIENT_HOME=$PWD/crypto-config/peerOrganizations/org1.example.com
FABRIC_CA_SERVER_TLS_CERTFILES=$PWD/crypto-config/peerOrganizations/org1.example.com/tlsca/ica.tls.orderer.example.com.key.pem
FABRIC_CA_SERVER_TLS_KEYFILE=$PWD/crypto-config/peerOrganizations/org1.example.com/tlsca/ica.tls.orderer.example.com.cert

fabric-ca-client enroll --caname ca --csr.names "${CSR_NAMES}" -m admin -u \
http://admin:adminpw@localhost:7054

sleep 30

fabric-ca-client register --caname ca --id.name Admin@org1.example.com \
--id.secret mysecret --id.type admin  -u \
http://localhost:7054

fabric-ca-client register --caname ca --id.name peer0.org1.example.com \
--id.secret mysecret --id.type peer  -u \
http://localhost:7054

export FABRIC_CA_CLIENT_HOME=$ADMIN_DIR

fabric-ca-client enroll --caname ca --csr.names "${CSR_NAMES}" -m \
Admin@org1.example.com -u http://Admin@org1.example.com:mysecret@localhost:7054

sleep 15

cp $ORG_DIR/ca/chain.identity.org1.example.com.cert $ADMIN_DIR/msp/chain.cert
cp $PWD/nodeou.yaml $ADMIN_DIR/msp/config.yaml


export FABRIC_CA_CLIENT_HOME=$PEER_DIR

fabric-ca-client enroll --caname ca --csr.names "${CSR_NAMES}" -m \
peer0.org1.example.com -u http://peer0.org1.example.com:mysecret@localhost:7054

cp $ORG_DIR/ca/chain.identity.org1.example.com.cert $PEER_DIR/msp/chain.cert
cp $PWD/nodeou.yaml $PEER_DIR/msp/config.yaml


export FABRIC_CA_CLIENT_HOME=$TLS_REGISTRAR_DIR
fabric-ca-client enroll --caname tlsca --csr.names "${CSR_NAMES}" -m admin \
--enrollment.profile tls \
-u http://admin:adminpw@localhost:7054

sleep 30

fabric-ca-client register --caname tlsca --id.name peer0.org1.example.com \
--id.secret mysecret --id.type peer  \
--enrollment.profile tls \
-u http://localhost:7054

export FABRIC_CA_CLIENT_HOME=$PEER_DIR/tls
fabric-ca-client enroll --caname tlsca --csr.names "${CSR_NAMES}" \
-m peer0.org1.example.com -u http://peer0.org1.example.com:mysecret@localhost:7054

cp $PEER_DIR/tls/msp/signcerts/*.pem $PEER_DIR/tls/server.crt
cp $PEER_DIR/tls/msp/keystore/* $PEER_DIR/tls/server.key

cat $PEER_DIR/tls/msp/intermediatecerts/*.pem \
$PEER_DIR/tls/msp/cacerts/*.pem > $PEER_DIR/tls/ca.crt

# rm -rf $PEER_DIR/tls/msp $PEER_DIR/tls/*.yaml

mkdir $ORG_DIR/msp/admincerts && cp $ORG_DIR/users/Admin@org1.example.com/msp/signcerts/cert.pem $ORG_DIR/msp/admincerts
mkdir $ORG_DIR/msp/tlscacerts && cp $PEER_DIR/tls/ca.crt $ORG_DIR/msp/tlscacerts 
cp -r $ORG_DIR/msp/admincerts $PEER_DIR/msp/admincerts
cp -r $ORG_DIR/msp/tlscacerts $PEER_DIR/msp/tlscacerts
