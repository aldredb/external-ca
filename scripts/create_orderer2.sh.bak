#!/bin/sh

export SUBJ="/C=TW/ST=Taiwan/L=Taiwan/O=orderer.example.com/CN="
export CSR_NAMES="C=TW,ST=Taiwan,L=Taiwan"
CSR_NAMES="C=TW,ST=Taiwan,L=Taiwan,O=orderer.example.com"
export CHANNEL_NAME="orderer-channel"

ORG_DIR=$PWD/crypto-config/ordererOrganizations/orderer.example.com
PEER_DIR=$ORG_DIR/orderers/$O
IDENTITY_REGISTRAR_DIR=$ORG_DIR/users/admin
TLS_REGISTRAR_DIR=$ORG_DIR/users/tlsadmin
ADMIN_DIR=$ORG_DIR/users/Admin@orderer.example.com

sudo docker-compose up -d ica.orderer.example.com

sleep 5

curl http://localhost:7055/cainfo\?ca\=ca
curl http://localhost:7055/cainfo\?ca\=tlsca

export FABRIC_CA_CLIENT_HOME=$PWD/crypto-config/ordererOrganizations/orderer.example.com
# CSR_NAMES="C=TW,ST=Taiwan,L=Taiwan,O=orderer.example.com"


fabric-ca-client enroll --caname ca --csr.names "${CSR_NAMES}" -m admin -u \
http://admin:adminpw@localhost:7055

sleep 20

fabric-ca-client register --caname ca --id.name Admin@orderer.example.com \
--id.secret mysecret --id.type admin -u \
http://localhost:7055

fabric-ca-client register --caname ca --id.name o1.orderer.example.com \
--id.secret mysecret --id.type orderer -u \
http://localhost:7055

fabric-ca-client register --caname ca --id.name o2.orderer.example.com \
--id.secret mysecret --id.type orderer -u \
http://localhost:7055

fabric-ca-client register --caname ca --id.name o3.orderer.example.com \
--id.secret mysecret --id.type orderer -u \
http://localhost:7055

#ORG_DIR=$PWD/crypto-config/ordererOrganizations/orderer.example.com
#ADMIN_DIR=$ORG_DIR/users/Admin@orderer.example.com
export FABRIC_CA_CLIENT_HOME=$ADMIN_DIR
fabric-ca-client enroll --caname ca --csr.names "${CSR_NAMES}" -m \
Admin@orderer.example.com -u http://Admin@orderer.example.com:mysecret@localhost:7055
cp $ORG_DIR/ca/chain.identity.orderer.example.com.cert \
$ADMIN_DIR/msp/chain.cert
cp $PWD/nodeou.yaml $ADMIN_DIR/msp/config.yaml

export PEER_DIR=$ORG_DIR/orderers/o1.orderer.example.com
export FABRIC_CA_CLIENT_HOME=$PEER_DIR
fabric-ca-client enroll --caname ca --csr.names "${CSR_NAMES}" -m \
o1.orderer.example.com -u http://o1.orderer.example.com:mysecret@localhost:7055
cp $ORG_DIR/ca/chain.identity.orderer.example.com.cert \
$PEER_DIR/msp/chain.cert
cp $PWD/nodeou.yaml $PEER_DIR/msp/config.yaml

export PEER_DIR=$ORG_DIR/orderers/o2.orderer.example.com
export FABRIC_CA_CLIENT_HOME=$PEER_DIR
fabric-ca-client enroll --caname ca --csr.names "${CSR_NAMES}" -m \
o2.orderer.example.com -u http://o2.orderer.example.com:mysecret@localhost:7055
cp $ORG_DIR/ca/chain.identity.orderer.example.com.cert \
$PEER_DIR/msp/chain.cert
cp $PWD/nodeou.yaml $PEER_DIR/msp/config.yaml

export PEER_DIR=$ORG_DIR/orderers/o3.orderer.example.com
export FABRIC_CA_CLIENT_HOME=$PEER_DIR
fabric-ca-client enroll --caname ca --csr.names "${CSR_NAMES}" -m \
o3.orderer.example.com -u http://o3.orderer.example.com:mysecret@localhost:7055
cp $ORG_DIR/ca/chain.identity.orderer.example.com.cert \
$PEER_DIR/msp/chain.cert
cp $PWD/nodeou.yaml $PEER_DIR/msp/config.yaml

sleep 5

export FABRIC_CA_CLIENT_HOME=$TLS_REGISTRAR_DIR
fabric-ca-client enroll --caname tlsca --csr.names "${CSR_NAMES}" -m admin \
-u http://admin:adminpw@localhost:7055


sleep 20

fabric-ca-client register --caname tlsca --id.name o1.orderer.example.com \
--id.secret mysecret --id.type orderer \
-u http://localhost:7055
fabric-ca-client register --caname tlsca --id.name o2.orderer.example.com \
--id.secret mysecret --id.type orderer \
-u http://localhost:7055
fabric-ca-client register --caname tlsca --id.name o3.orderer.example.com \
--id.secret mysecret --id.type orderer \
-u http://localhost:7055

export FABRIC_CA_CLIENT_HOME=$ORG_DIR/orderers/o1.orderer.example.com/tls
fabric-ca-client enroll --caname tlsca --csr.names "${CSR_NAMES}" \
-m o1.orderer.example.com -u http://o1.orderer.example.com:mysecret@localhost:7055
export FABRIC_CA_CLIENT_HOME=$ORG_DIR/orderers/o2.orderer.example.com/tls
fabric-ca-client enroll --caname tlsca --csr.names "${CSR_NAMES}" \
-m o2.orderer.example.com -u http://o2.orderer.example.com:mysecret@localhost:7055
export FABRIC_CA_CLIENT_HOME=$ORG_DIR/orderers/o3.orderer.example.com/tls
fabric-ca-client enroll --caname tlsca --csr.names "${CSR_NAMES}" \
-m o3.orderer.example.com -u http://o3.orderer.example.com:mysecret@localhost:7055


export PEER_DIR=$ORG_DIR/orderers/o1.orderer.example.com
cp $PEER_DIR/tls/msp/signcerts/*.pem $PEER_DIR/tls/server.crt
cp $PEER_DIR/tls/msp/keystore/* $PEER_DIR/tls/server.key

cat $PEER_DIR/tls/msp/intermediatecerts/*.pem \
$PEER_DIR/tls/msp/cacerts/*.pem > $PEER_DIR/tls/ca.crt

rm -rf $PEER_DIR/tls/msp $PEER_DIR/tls/*.yaml

export PEER_DIR=$ORG_DIR/orderers/o2.orderer.example.com
cp $PEER_DIR/tls/msp/signcerts/*.pem $PEER_DIR/tls/server.crt
cp $PEER_DIR/tls/msp/keystore/* $PEER_DIR/tls/server.key

cat $PEER_DIR/tls/msp/intermediatecerts/*.pem \
$PEER_DIR/tls/msp/cacerts/*.pem > $PEER_DIR/tls/ca.crt

rm -rf $PEER_DIR/tls/msp $PEER_DIR/tls/*.yaml


export PEER_DIR=$ORG_DIR/orderers/o3.orderer.example.com
cp $PEER_DIR/tls/msp/signcerts/*.pem $PEER_DIR/tls/server.crt
cp $PEER_DIR/tls/msp/keystore/* $PEER_DIR/tls/server.key

cat $PEER_DIR/tls/msp/intermediatecerts/*.pem \
$PEER_DIR/tls/msp/cacerts/*.pem > $PEER_DIR/tls/ca.crt

rm -rf $PEER_DIR/tls/msp $PEER_DIR/tls/*.yaml


cd ./crypto-config/ordererOrganizations/orderer.example.com/users/Admin@orderer.example.com/msp
mkdir admincerts
cp signcerts/cert.pem admincerts/Admin@orderer.example.com
# back to home path
cd -
cd ./crypto-config/ordererOrganizations/orderer.example.com/orderers/o1.orderer.example.com/msp
cp -r ../../../users/Admin@orderer.example.com/msp/admincerts .
cd -
