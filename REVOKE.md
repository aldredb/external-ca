# Revoke Intermediate CA

```bash
openssl ca -revoke crypto-config/peerOrganizations/org1.example.com/ca/ica.identity.org1.example.com.cert -config openssl_root-identity.cnf
openssl ca -gencrl -config openssl_root-identity.cnf -out identity-rca/crl/crls
export FLAG=$(if [ "$(uname -s)" == "Linux" ]; then echo "-d"; else echo "-b 0"; fi)
CRL=$(cat identity-rca/crl/crls | base64 $FLAG)
```

Generate certificate-key pairs and chain file for the new ICA

```bash
mkdir -p newica
openssl ecparam -name prime256v1 -genkey -noout -out newica/newica.identity.org1.example.com.key

openssl req -new -sha256 -key newica/newica.identity.org1.example.com.key -out newica/newica.identity.org1.example.com.csr -subj "/C=SG/ST=Singapore/L=Singapore/O=org1.example.com/OU=/CN=newica.identity.org1.example.com"

openssl ca -batch -config openssl_root-identity.cnf -extensions v3_intermediate_ca -days 1825 -notext -md sha256 -in newica/newica.identity.org1.example.com.csr -out newica/newica.identity.org1.example.com.cert

cat newica/newica.identity.org1.example.com.cert $PWD/identity-rca/certs/rca.identity.org1.example.com.cert > newica/newchain.identity.org1.example.com.cert
```

Start new ICA

```bash
docker-compose up -d newica.org1.example.com

curl http://localhost:8054/cainfo\?ca\=ca
```

Wait for 1 minute

Enroll new ICA's registrar

```bash
NEW_IDENTITY_REGISTRAR_DIR=crypto-config/peerOrganizations/org1.example.com/users/newadmin
mkdir -p $NEW_IDENTITY_REGISTRAR_DIR
export FABRIC_CA_CLIENT_HOME=$NEW_IDENTITY_REGISTRAR_DIR
fabric-ca-client enroll --caname ca --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -m admin -u http://admin:adminpw@localhost:8054
```

Register and enroll a new user called `newadmin@org1.example.com` which will be the new organization administrator

```bash
fabric-ca-client register --caname ca --id.name newadmin@org1.example.com --id.secret mysecret --id.type admin --id.affiliation org1  -u http://localhost:8054

NEWADMIN_DIR=crypto-config/peerOrganizations/org1.example.com/users/newadmin@org1.example.com
mkdir -p $NEWADMIN_DIR
export FABRIC_CA_CLIENT_HOME=$NEWADMIN_DIR
fabric-ca-client enroll --caname ca --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -u http://newadmin@org1.example.com:mysecret@localhost:8054
mkdir -p $NEWADMIN_DIR/msp/admincerts
cp $NEWADMIN_DIR/msp/signcerts/cert.pem $NEWADMIN_DIR/msp/admincerts
```

Add intermediate cert and new admin cert into the channel configuration

```bash
source utils.sh
```

```bash
retrieve_current_config update1 channel1 Org1MSP \
  /var/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  orderer.example.com:7050 \
  /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem

NEWICA=$(cat newica/newica.identity.org1.example.com.cert | base64 $FLAG)
NEWADMIN=$(cat $NEWADMIN_DIR/msp/signcerts/cert.pem | base64 $FLAG)

WORKING_DIR=/config/channel1_update1
docker exec -e "WORKING_DIR=$WORKING_DIR" -e "NEWICA=$NEWICA" cli \
  sh -c 'jq ".channel_group.groups.Application.groups.Org1MSP.values.MSP.value.config.intermediate_certs |= . + [\"$NEWICA\"]" $WORKING_DIR/current_config.json \
  > $WORKING_DIR/tmp_config.json'

docker exec -e "WORKING_DIR=$WORKING_DIR" -e "NEWADMIN=$NEWADMIN" cli \
  sh -c 'jq ".channel_group.groups.Application.groups.Org1MSP.values.MSP.value.config.admins |= . + [\"$NEWADMIN\"]" $WORKING_DIR/tmp_config.json \
  > $WORKING_DIR/modified_config.json'

prepare_unsigned_modified_config update1 channel1

send_config_update update1 channel1 Org1MSP \
  /var/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  orderer.example.com:7050 \
  /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem

retrieve_updated_config update1 channel1 Org1MSP \
  /var/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  orderer.example.com:7050 \
  /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem
```

Add the CRL into the channel configuration

```bash
retrieve_current_config update2 channel1 Org1MSP \
  /var/crypto/peerOrganizations/org1.example.com/users/newadmin@org1.example.com/msp \
  orderer.example.com:7050 \
  /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem

WORKING_DIR=/config/channel1_update2
docker exec -e "WORKING_DIR=$WORKING_DIR" -e "CRL=$CRL" cli \
  sh -c 'jq ".channel_group.groups.Application.groups.Org1MSP.values.MSP.value.config.revocation_list |= . + [\"$CRL\"]" $WORKING_DIR/current_config.json \
  > $WORKING_DIR/tmp1_config.json'

docker exec -e "WORKING_DIR=$WORKING_DIR" cli \
  sh -c 'jq "del(.channel_group.groups.Application.groups.Org1MSP.values.MSP.value.config.admins[0])" $WORKING_DIR/tmp1_config.json \
  > $WORKING_DIR/tmp2_config.json'

docker exec -e "WORKING_DIR=$WORKING_DIR" cli \
  sh -c 'jq "del(.channel_group.groups.Application.groups.Org1MSP.values.MSP.value.config.intermediate_certs[0])" $WORKING_DIR/tmp2_config.json \
  > $WORKING_DIR/modified_config.json'

prepare_unsigned_modified_config update2 channel1

send_config_update update2 channel1 Org1MSP \
  /var/crypto/peerOrganizations/org1.example.com/users/newadmin@org1.example.com/msp \
  orderer.example.com:7050 \
  /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem
```

Invoke

```bash
docker exec cli \
  peer chaincode invoke -o orderer.example.com:7050 --tls \
  --cafile /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  -C channel1 -n chaincode1 -c '{"Args":["put", "y", "1"]}' --waitForEvent
```

```bash
Error: error sending transaction for invoke: got unexpected status: FORBIDDEN -- implicit policy evaluation failed - 0 sub-policies were satisfied, but this policy requires 1 of the 'Writers' sub-policies to be satisfied: permission denied
```

Query

```bash
docker exec cli peer chaincode query -C channel1 -n chaincode1 -c '{"Args":["query","a"]}'
```

Stop the peer container

```bash
docker stop peer0.org1.example.com
```

Backup peer certificate and key

```bash
ORG_DIR=$PWD/crypto-config/peerOrganizations/org1.example.com
PEER_DIR=$ORG_DIR/peers/peer0.org1.example.com
mv $PEER_DIR/msp $PEER_DIR/msp-bak
```

```bash
export FABRIC_CA_CLIENT_HOME=$NEW_IDENTITY_REGISTRAR_DIR
fabric-ca-client register --caname ca --id.name newpeer0@org1.example.com --id.secret mysecret --id.type peer --id.affiliation org1 -u http://localhost:8054

export FABRIC_CA_CLIENT_HOME=$PEER_DIR
fabric-ca-client enroll --caname ca --csr.names C=SG,ST=Singapore,L=Singapore,O=org1.example.com -u http://newpeer0@org1.example.com:mysecret@localhost:8054

mkdir -p $PEER_DIR/msp/admincerts
cp $NEWADMIN_DIR/msp/signcerts/cert.pem $PEER_DIR/msp/admincerts
```

Start the peer container

```bash
docker start peer0.org1.example.com
```

Try to invoke once more

```bash
docker exec -e "CORE_PEER_MSPCONFIGPATH=/var/crypto/peerOrganizations/org1.example.com/users/newadmin@org1.example.com/msp" cli \
  peer chaincode invoke -o orderer.example.com:7050 --tls \
  --cafile /var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  -C channel1 -n chaincode1 -c '{"Args":["put", "y", "1"]}' --waitForEvent
```
