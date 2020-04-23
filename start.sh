#/bin/sh

set -e

export PATH=$PWD/bin:$PATH
export FABRIC_CFG_PATH=${PWD}

echo "Generating crypto-materials for Orderer Org.."
cryptogen generate --config=./crypto-config.yaml

ORG_DIR=$PWD/crypto-config/peerOrganizations/org1.example.com
PEER_DIR=$ORG_DIR/peers/peer0.org1.example.com
IDENTITY_REGISTRAR_DIR=$ORG_DIR/users/admin
TLS_REGISTRAR_DIR=$ORG_DIR/users/tlsadmin
ADMIN_DIR=$ORG_DIR/users/Admin@org1.example.com
mkdir -p $ORG_DIR/ca $ORG_DIR/tlsca $ORG_DIR/msp $PEER_DIR $IDENTITY_REGISTRAR_DIR $TLS_REGISTRAR_DIR $ADMIN_DIR

echo "Creating Identity Root CA.."
mkdir -p identity-rca/private identity-rca/certs identity-rca/newcerts identity-rca/crl
touch identity-rca/index.txt identity-rca/serial
echo 1000 > identity-rca/serial
echo 1000 > identity-rca/crlnumber
openssl ecparam -name prime256v1 -genkey -noout -out identity-rca/private/rca.identity.org1.example.com.key
openssl req -config openssl_root-identity.cnf -new -x509 -sha256 -extensions v3_ca -key identity-rca/private/rca.identity.org1.example.com.key -out identity-rca/certs/rca.identity.org1.example.com.cert -days 3650 -subj "/C=SG/ST=Singapore/L=Singapore/O=org1.example.com/OU=/CN=rca.identity.org1.example.com"

echo "Creating TLS Root CA.."
mkdir -p tls-rca/private tls-rca/certs tls-rca/newcerts tls-rca/crl
touch tls-rca/index.txt tls-rca/serial
echo 1000 > tls-rca/serial
echo 1000 > tls-rca/crlnumber
openssl ecparam -name prime256v1 -genkey -noout -out tls-rca/private/rca.tls.org1.example.com.key
openssl req -config openssl_root-tls.cnf -new -x509 -sha256 -extensions v3_ca -key tls-rca/private/rca.tls.org1.example.com.key -out tls-rca/certs/rca.tls.org1.example.com.cert -days 3650 -subj "/C=SG/ST=Singapore/L=Singapore/O=org1.example.com/OU=/CN=rca.tls.org1.example.com"

echo "Creating and signing Identity Intermediate CA Cert.."
openssl ecparam -name prime256v1 -genkey -noout -out $ORG_DIR/ca/ica.identity.org1.example.com.key
openssl req -new -sha256 -key $ORG_DIR/ca/ica.identity.org1.example.com.key -out $ORG_DIR/ca/ica.identity.org1.example.com.csr -subj "/C=SG/ST=Singapore/L=Singapore/O=org1.example.com/OU=/CN=ica.identity.org1.example.com"
openssl ca -batch -config openssl_root-identity.cnf -extensions v3_intermediate_ca -days 1825 -notext -md sha256 -in $ORG_DIR/ca/ica.identity.org1.example.com.csr -out $ORG_DIR/ca/ica.identity.org1.example.com.cert
cat $ORG_DIR/ca/ica.identity.org1.example.com.cert $PWD/identity-rca/certs/rca.identity.org1.example.com.cert > $ORG_DIR/ca/chain.identity.org1.example.com.cert

echo "Creating and signing TLS Intermediate CA Cert.."
openssl ecparam -name prime256v1 -genkey -noout -out $ORG_DIR/tlsca/ica.tls.org1.example.com.key
openssl req -new -sha256 -key $ORG_DIR/tlsca/ica.tls.org1.example.com.key -out $ORG_DIR/tlsca/ica.tls.org1.example.com.csr -subj "/C=SG/ST=Singapore/L=Singapore/O=org1.example.com/OU=/CN=ica.tls.org1.example.com"
openssl ca -batch -config openssl_root-tls.cnf -extensions v3_intermediate_ca -days 1825 -notext -md sha256 -in $ORG_DIR/tlsca/ica.tls.org1.example.com.csr -out $ORG_DIR/tlsca/ica.tls.org1.example.com.cert
cat $ORG_DIR/tlsca/ica.tls.org1.example.com.cert $PWD/tls-rca/certs/rca.tls.org1.example.com.cert > $ORG_DIR/tlsca/chain.tls.org1.example.com.cert

echo "Starting Intermediate CA.."
docker-compose up -d ica.org1.example.com
echo "Sleeping for 1 minute before creating peer and user certs.."
sleep 60

echo "Registering and Enrolling Peer and User Identities.."
export FABRIC_CA_CLIENT_HOME=$IDENTITY_REGISTRAR_DIR
fabric-ca-client enroll --caname ca --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -m admin -u http://admin:adminpw@localhost:7054

echo "Sleeping for 30 seconds.."
sleep 35

fabric-ca-client register --caname ca --id.name Admin@org1.example.com --id.secret mysecret --id.type client --id.affiliation org1 -u http://localhost:7054
fabric-ca-client register --caname ca --id.name peer0.org1.example.com --id.secret mysecret --id.type peer --id.affiliation org1 -u http://localhost:7054

export FABRIC_CA_CLIENT_HOME=$ADMIN_DIR
fabric-ca-client enroll --caname ca --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -m Admin@org1.example.com -u http://Admin@org1.example.com:mysecret@localhost:7054
mkdir -p $ADMIN_DIR/msp/admincerts && cp $ADMIN_DIR/msp/signcerts/*.pem $ADMIN_DIR/msp/admincerts/

export FABRIC_CA_CLIENT_HOME=$PEER_DIR
fabric-ca-client enroll --caname ca --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -m peer0.org1.example.com -u http://peer0.org1.example.com:mysecret@localhost:7054
mkdir -p $PEER_DIR/msp/admincerts && cp $ADMIN_DIR/msp/signcerts/*.pem $PEER_DIR/msp/admincerts/

echo "Registering and Enrolling Peer TLS Certificate-Key pair.."
export FABRIC_CA_CLIENT_HOME=$TLS_REGISTRAR_DIR
fabric-ca-client enroll --caname tlsca --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -m admin -u http://admin:adminpw@localhost:7054

echo "Sleeping for 30 seconds.."
sleep 35

fabric-ca-client register --caname tlsca --id.name peer0.org1.example.com --id.secret mysecret --id.type peer --id.affiliation org1 -u http://localhost:7054
export FABRIC_CA_CLIENT_HOME=$PEER_DIR/tls
fabric-ca-client enroll --caname tlsca --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -m peer0.org1.example.com -u http://peer0.org1.example.com:mysecret@localhost:7054
cp $PEER_DIR/tls/msp/signcerts/*.pem $PEER_DIR/tls/server.crt
cp $PEER_DIR/tls/msp/keystore/* $PEER_DIR/tls/server.key
cat $PEER_DIR/tls/msp/intermediatecerts/*.pem $PEER_DIR/tls/msp/cacerts/*.pem > $PEER_DIR/tls/ca.crt
rm -rf $PEER_DIR/tls/msp $PEER_DIR/tls/*.yaml

echo "Preparing Org1 MSP.."
mkdir -p $ORG_DIR/msp/admincerts $ORG_DIR/msp/intermediatecerts $ORG_DIR/msp/cacerts $ORG_DIR/msp/tlscacerts $ORG_DIR/msp/tlsintermediatecerts
cp $ADMIN_DIR/msp/signcerts/*.pem $ORG_DIR/msp/admincerts/
cp $PEER_DIR/msp/cacerts/*.pem $ORG_DIR/msp/cacerts/
cp $PEER_DIR/msp/intermediatecerts/*.pem $ORG_DIR/msp/intermediatecerts/
cp $PWD/tls-rca/certs/rca.tls.org1.example.com.cert $ORG_DIR/msp/tlscacerts/
cp $ORG_DIR/tlsca/ica.tls.org1.example.com.cert $ORG_DIR/msp/tlsintermediatecerts/

echo "Generating Orderer Genesis Block and Channel Transaction.."
export FABRIC_CFG_PATH=${PWD}
configtxgen -profile OrdererGenesis -outputBlock ./config/genesis.block -channelID testchainid
configtxgen -profile Channel -outputCreateChannelTx ./config/channel1.tx -channelID channel1

echo "Starting Orderer, Peer and CLI.."
docker-compose up -d orderer.example.com peer0.org1.example.com cli

echo "Sleeping for 20 seconds.."
sleep 20

echo "Creating Channel channel1.."
docker exec cli peer channel create -o orderer.example.com:7050 --tls --cafile /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem -c channel1 -f /config/channel1.tx

echo "Joining Peer to channel1.."
docker exec cli peer channel join -b channel1.block

echo "Installing Chaincode.."
docker exec cli peer chaincode install -n chaincode1 -p github.com/chaincode1 -v 1

echo "Instantiating Chaincode.."
docker exec cli peer chaincode instantiate -o orderer.example.com:7050 --tls --cafile /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C channel1 -n chaincode1 -l "golang" -v 1 -c '{"Args":["init","a","81","b","11"]}' -P "OR('Org1MSP.member')"
sleep 5

echo "Invoking Chaincode.."
docker exec cli peer chaincode invoke -o orderer.example.com:7050 --tls --cafile /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C channel1 -n chaincode1 -c '{"Args":["put", "z", "7"]}' --waitForEvent

echo "Querying Chaincode.."
docker exec cli peer chaincode query -C channel1 -n chaincode1 -c '{"Args":["query","a"]}'