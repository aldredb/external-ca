#/bin/bash

set -e
source utils.sh

echo "Revoking Identity ICA"
openssl ca -revoke crypto-config/peerOrganizations/org1.example.com/ca/ica.identity.org1.example.com.cert -config openssl_root-identity.cnf
openssl ca -gencrl -config openssl_root-identity.cnf -out identity-rca/crl/crls
export FLAG=$(if [ "$(uname -s)" == "Linux" ]; then echo "-d"; else echo "-b 0"; fi)
CRL=$(cat identity-rca/crl/crls | base64 $FLAG)

echo "Generating certificate-key pairs and chain file for the new ICA"
mkdir -p newica
openssl ecparam -name prime256v1 -genkey -noout -out newica/newica.identity.org1.example.com.key
openssl req -new -sha256 -key newica/newica.identity.org1.example.com.key -out newica/newica.identity.org1.example.com.csr -subj "/C=SG/ST=Singapore/L=Singapore/O=org1.example.com/OU=/CN=newica.identity.org1.example.com"
openssl ca -batch -config openssl_root-identity.cnf -extensions v3_intermediate_ca -days 1825 -notext -md sha256 -in newica/newica.identity.org1.example.com.csr -out newica/newica.identity.org1.example.com.cert
cat newica/newica.identity.org1.example.com.cert $PWD/identity-rca/certs/rca.identity.org1.example.com.cert > newica/newchain.identity.org1.example.com.cert

echo "Starting new ICA"
docker-compose up -d newica.org1.example.com

echo "Sleeping for 1 minute"
sleep 60

echo "Enrolling Registrar.."
NEW_IDENTITY_REGISTRAR_DIR=crypto-config/peerOrganizations/org1.example.com/users/newadmin
mkdir -p $NEW_IDENTITY_REGISTRAR_DIR
export FABRIC_CA_CLIENT_HOME=$NEW_IDENTITY_REGISTRAR_DIR
fabric-ca-client enroll --caname ca --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -m admin -u http://admin:adminpw@localhost:8054
echo "Sleeping for 30 seconds.."
sleep 35

echo "Register and enroll new org admin.."
fabric-ca-client register --caname ca --id.name newadmin@org1.example.com --id.secret mysecret --id.type admin --id.affiliation org1  -u http://localhost:8054
NEWADMIN_DIR=crypto-config/peerOrganizations/org1.example.com/users/newadmin@org1.example.com
mkdir -p $NEWADMIN_DIR
export FABRIC_CA_CLIENT_HOME=$NEWADMIN_DIR
fabric-ca-client enroll --caname ca --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -u http://newadmin@org1.example.com:mysecret@localhost:8054
mkdir -p $NEWADMIN_DIR/msp/admincerts
cp $NEWADMIN_DIR/msp/signcerts/cert.pem $NEWADMIN_DIR/msp/admincerts

echo "Perform channel configuration update.."
NEWICA=$(cat newica/newica.identity.org1.example.com.cert | base64 $FLAG)
NEWADMIN=$(cat $NEWADMIN_DIR/msp/signcerts/cert.pem | base64 $FLAG)
WORKING_DIR=/config/channel1_update1

retrieve_current_config update1 channel1 Org1MSP \
  /var/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  orderer.example.com:7050 \
  /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem

  docker exec -e "WORKING_DIR=$WORKING_DIR" -e "CRL=$CRL" cli \
  sh -c 'jq ".channel_group.groups.Application.groups.Org1MSP.values.MSP.value.config.revocation_list |= . + [\"$CRL\"]" $WORKING_DIR/current_config.json \
  > $WORKING_DIR/tmp1_config.json'

docker exec -e "WORKING_DIR=$WORKING_DIR" cli \
  sh -c 'jq "del(.channel_group.groups.Application.groups.Org1MSP.values.MSP.value.config.admins[0])" $WORKING_DIR/tmp1_config.json \
  > $WORKING_DIR/tmp2_config.json'

docker exec -e "WORKING_DIR=$WORKING_DIR" cli \
  sh -c 'jq "del(.channel_group.groups.Application.groups.Org1MSP.values.MSP.value.config.intermediate_certs[0])" $WORKING_DIR/tmp2_config.json \
  > $WORKING_DIR/tmp3_config.json'

docker exec -e "WORKING_DIR=$WORKING_DIR" -e "NEWICA=$NEWICA" cli \
  sh -c 'jq ".channel_group.groups.Application.groups.Org1MSP.values.MSP.value.config.intermediate_certs |= . + [\"$NEWICA\"]" $WORKING_DIR/tmp3_config.json \
  > $WORKING_DIR/tmp4_config.json'

docker exec -e "WORKING_DIR=$WORKING_DIR" -e "NEWADMIN=$NEWADMIN" cli \
  sh -c 'jq ".channel_group.groups.Application.groups.Org1MSP.values.MSP.value.config.admins |= . + [\"$NEWADMIN\"]" $WORKING_DIR/tmp4_config.json \
  > $WORKING_DIR/modified_config.json'

prepare_unsigned_modified_config update1 channel1

send_config_update update1 channel1 Org1MSP \
  /var/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  orderer.example.com:7050 \
  /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem

sleep 5

retrieve_updated_config update1 channel1 Org1MSP \
  /var/crypto/peerOrganizations/org1.example.com/users/newadmin@org1.example.com/msp \
  orderer.example.com:7050 \
  /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem


echo "Stopping peer container.."
docker stop peer0.org1.example.com

echo "Backup peer identity certificate and key.."
ORG_DIR=$PWD/crypto-config/peerOrganizations/org1.example.com
PEER_DIR=$ORG_DIR/peers/peer0.org1.example.com
mv $PEER_DIR/msp $PEER_DIR/msp-bak

echo "Register and enroll new peer identity certificate and key"
export FABRIC_CA_CLIENT_HOME=$NEW_IDENTITY_REGISTRAR_DIR
fabric-ca-client register --caname ca --id.name newpeer0@org1.example.com --id.secret mysecret --id.type peer --id.affiliation org1 -u http://localhost:8054

echo "Sleeping for 30 seconds"
sleep 35

export FABRIC_CA_CLIENT_HOME=$PEER_DIR
fabric-ca-client enroll --caname ca --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -u http://newpeer0@org1.example.com:mysecret@localhost:8054
mkdir -p $PEER_DIR/msp/admincerts
cp $NEWADMIN_DIR/msp/signcerts/cert.pem $PEER_DIR/msp/admincerts

echo "Starting peer container.."
docker start peer0.org1.example.com

echo "Sleeping for 20 seconds"
sleep 20

echo "Invoking Chaincode.."
docker exec -e "CORE_PEER_MSPCONFIGPATH=/var/crypto/peerOrganizations/org1.example.com/users/newadmin@org1.example.com/msp" cli \
  peer chaincode invoke -o orderer.example.com:7050 --tls \
  --cafile /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  -C channel1 -n chaincode1 -c '{"Args":["put", "y", "1"]}' --waitForEvent

echo "Querying Chaincode.."
docker exec -e "CORE_PEER_MSPCONFIGPATH=/var/crypto/peerOrganizations/org1.example.com/users/newadmin@org1.example.com/msp" cli \
  peer chaincode query -C channel1 -n chaincode1 -c '{"Args":["query","y"]}'