#!/bin/sh

export SUBJ="/C=TW/ST=Taiwan/L=Taiwan/O=org1.example.com/CN="
export CSR_NAMES="C=TW,ST=Taiwan,L=Taiwan,O=org1.example.com"
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
# CSR_NAMES="C=TW,ST=Taiwan,L=Taiwan,O=org1.example.com"

fabric-ca-client enroll --caname ca --csr.names "${CSR_NAMES}" -m admin -u \
http://admin:adminpw@localhost:7054

sleep 15

fabric-ca-client register --caname ca --id.name Admin@org1.example.com \
--id.secret mysecret --id.type admin  -u \
http://localhost:7054

fabric-ca-client register --caname ca --id.name peer0.org1.example.com \
--id.secret mysecret --id.type peer  -u \
http://localhost:7054


#ORG_DIR=$PWD/crypto-config/peerOrganizations/org1.example.com
#ADMIN_DIR=$ORG_DIR/users/Admin@org1.example.com
export FABRIC_CA_CLIENT_HOME=$ADMIN_DIR


fabric-ca-client enroll --caname ca --csr.names "${CSR_NAMES}" -m \
Admin@org1.example.com -u http://Admin@org1.example.com:mysecret@localhost:7054


cp $ORG_DIR/ca/chain.identity.org1.example.com.cert $ADMIN_DIR/msp/chain.cert
cp $PWD/nodeou.yaml $ADMIN_DIR/msp/config.yaml

export FABRIC_CA_CLIENT_HOME=$PEER_DIR

fabric-ca-client enroll --caname ca --csr.names "${CSR_NAMES}" -m \
peer0.org1.example.com -u http://peer0.org1.example.com:mysecret@localhost:7054


cp $ORG_DIR/ca/chain.identity.org1.example.com.cert $PEER_DIR/msp/chain.cert
cp $PWD/nodeou.yaml $PEER_DIR/msp/config.yaml


export FABRIC_CA_CLIENT_HOME=$TLS_REGISTRAR_DIR
fabric-ca-client enroll --caname tlsca --csr.names "${CSR_NAMES}" -m admin \
-u http://admin:adminpw@localhost:7054

sleep 15

fabric-ca-client register --caname tlsca --id.name peer0.org1.example.com \
--id.secret mysecret --id.type peer  \
-u http://localhost:7054

export FABRIC_CA_CLIENT_HOME=$PEER_DIR/tls
fabric-ca-client enroll --caname tlsca --csr.names "${CSR_NAMES}" \
-m peer0.org1.example.com -u http://peer0.org1.example.com:mysecret@localhost:7054

cp $PEER_DIR/tls/msp/signcerts/*.pem $PEER_DIR/tls/server.crt
cp $PEER_DIR/tls/msp/keystore/* $PEER_DIR/tls/server.key

cat $PEER_DIR/tls/msp/intermediatecerts/*.pem \
$PEER_DIR/tls/msp/cacerts/*.pem > $PEER_DIR/tls/ca.crt

#rm -rf $PEER_DIR/tls/msp $PEER_DIR/tls/*.yaml

#PEER_DIR=crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/users/admin
cp $PEER_DIR/msp/cacerts/*.pem $ORG_DIR/msp/cacerts/
cp $PEER_DIR/msp/intermediatecerts/*.pem $ORG_DIR/msp/intermediatecerts/
cp $PWD/tls-rca/certs/rca.tls.org1.example.com.cert $ORG_DIR/msp/tlscacerts/
cp $ORG_DIR/tlsca/ica.tls.org1.example.com.cert $ORG_DIR/msp/tlsintermediatecerts/

cp $ORG_DIR/ca/chain.identity.org1.example.com.cert $ORG_DIR/msp/chain.cert
cp $PWD/nodeou.yaml $ORG_DIR/msp/config.yaml

