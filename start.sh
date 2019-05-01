#/bin/sh

set -e

export PATH=$PWD/bin:$PATH
export FABRIC_CFG_PATH=${PWD}
cryptogen generate --config=./crypto-config.yaml

ORG_DIR=$PWD/crypto-config/peerOrganizations/org1.example.com
PEER_DIR=$ORG_DIR/peers/peer0.org1.example.com
REGISTRAR_DIR=$ORG_DIR/users/admin
ADMIN_DIR=$ORG_DIR/users/Admin@org1.example.com
mkdir -p $ORG_DIR/ca $ORG_DIR/msp $PEER_DIR $REGISTRAR_DIR $ADMIN_DIR

mkdir -p rca/private rca/certs rca/newcerts
touch rca/index.txt rca/serial
echo 1000 > rca/serial
openssl ecparam -name prime256v1 -genkey -noout -out rca/private/rca.org1.example.com.key.pem
openssl req -config openssl_root.cnf -new -x509 -sha256 -extensions v3_ca -key rca/private/rca.org1.example.com.key.pem -out rca/certs/rca.org1.example.com.crt.pem -days 3650 -set_serial 0 -subj "/C=SG/ST=Singapore/L=Singapore/O=org1.example.com/OU=/CN=rca.org1.example.com"

openssl ecparam -name prime256v1 -genkey -noout -out $ORG_DIR/ca/ica.org1.example.com.key.pem

openssl req -new -sha256 -key $ORG_DIR/ca/ica.org1.example.com.key.pem -out $ORG_DIR/ca/ica.org1.example.com.csr -subj "/C=SG/ST=Singapore/L=Singapore/O=org1.example.com/OU=/CN=ica.org1.example.com"

openssl ca -batch -config openssl_root.cnf -extensions v3_intermediate_ca -days 3650 -notext -md sha256 -in $ORG_DIR/ca/ica.org1.example.com.csr -out $ORG_DIR/ca/ica.org1.example.com.crt.pem

cat $ORG_DIR/ca/ica.org1.example.com.crt.pem $PWD/rca/certs/rca.org1.example.com.crt.pem > $ORG_DIR/ca/chain.org1.example.com.crt.pem

docker-compose up -d ica.org1.example.com
sleep 5

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

mkdir -p $ORG_DIR/msp/admincerts $ORG_DIR/msp/intermediatecerts $ORG_DIR/msp/cacerts
cp $ADMIN_DIR/msp/signcerts/*.pem $ORG_DIR/msp/admincerts/
cp $PEER_DIR/msp/cacerts/*.pem $ORG_DIR/msp/cacerts/
cp $PEER_DIR/msp/intermediatecerts/*.pem $ORG_DIR/msp/intermediatecerts/

configtxgen -profile OrdererGenesis -outputBlock ./config/genesis.block -channelID testchainid
configtxgen -profile Channel -outputCreateChannelTx ./config/channel1.tx -channelID channel1