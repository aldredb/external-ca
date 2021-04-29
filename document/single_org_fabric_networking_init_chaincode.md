# Single Org fabric networking init chaincode

```
MYCHANNEL=external-ca-channel
SEQNUMBER=1
LABELNAME=marbles02
CVERSION=1.0
ORDERER_TLS=/var/crypto/ordererOrganizations/orderer.example.com/msp/tlscacerts/tlsca.orderer.example.com-cert.pem
#CORE_PEER_MSPCONFIGPATH=/var/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp


peer channel create -o o1.orderer.example.com:7050 --tls --cafile $ORDERER_TLS -c ${MYCHANNEL} -f /config/${MYCHANNEL}.tx

mv ${MYCHANNEL}.block /config/
peer channel join -b /config/${MYCHANNEL}.block

# run on org1
peer channel update -o o1.orderer.example.com:7050 --tls --cafile $ORDERER_TLS -c ${MYCHANNEL} -f /config/channel-artifacts/${MYCHANNEL}_Org1MSPanchors.tx

# == run with each machine == #
peer lifecycle chaincode package marbles02.tar.gz --path /opt/gopath/src/github.com/marbles02/go --lang golang --label marbles02

peer lifecycle chaincode install marbles02.tar.gz
peer lifecycle chaincode queryinstalled

# please replace with query result
CC_PACKAGE_ID=marbles02:44f6c99305968f5d8723827637870836d85cb031934ab39deea35810d8681edc

peer lifecycle chaincode approveformyorg --channelID $MYCHANNEL -o o1.orderer.example.com:7050 \
--ordererTLSHostnameOverride o1.orderer.example.com \
--name marbles02 --version $CVERSION --init-required --package-id $CC_PACKAGE_ID --sequence $SEQNUMBER --tls true --cafile $ORDERER_TLS
# == run with each machine == #

peer lifecycle chaincode checkcommitreadiness --channelID $MYCHANNEL --name $LABELNAME --version $CVERSION --init-required --sequence $SEQNUMBER --tls true --cafile $ORDERER_TLS --output json

peer lifecycle chaincode commit -o o1.orderer.example.com:7050 --channelID $MYCHANNEL --name $LABELNAME --version $CVERSION --sequence $SEQNUMBER --init-required --tls true --cafile \
$ORDERER_TLS \
--peerAddresses peer0.org1.example.com:7051 \
--tlsRootCertFiles /var/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt



peer chaincode invoke -o o1.orderer.example.com:7050 --isInit --tls true \
--cafile $ORDERER_TLS \
-C $MYCHANNEL -n $LABELNAME \
--peerAddresses peer0.org1.example.com:7051 \
--tlsRootCertFiles /var/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt



peer chaincode invoke -o o1.orderer.example.com:7050 --tls true \
--cafile $ORDERER_TLS \
-C $MYCHANNEL -n $LABELNAME --peerAddresses peer0.org1.example.com:7051 \
--tlsRootCertFiles /var/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
-c '{"Args":["initMarble","marble2","red","38","mama"]}' --waitForEvent

peer chaincode query -C $MYCHANNEL -n marbles02 -c '{"Args":["readMarble","marble2"]}'

```
