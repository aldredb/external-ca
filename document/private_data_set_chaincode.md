# Private Data Set Chaincode

## copy chaincode
```
CILCONATINERNAME=org1-cli
docker cp ~/fabric-samples/asset-transfer-private-data/chaincode-go $CILCONATINERNAME:/
```
## docker on cli docker
```
mkdir -p /opt/gopath/src/github.com/hyperledger/fabric-samples/asset-transfer-private-data
mv /chaincode-go /opt/gopath/src/github.com/hyperledger/fabric-samples/asset-transfer-private-data
cd /opt/gopath/src/github.com/hyperledger/fabric-samples/asset-transfer-private-data/chaincode-go && go mod vendor
```

## pack & install cli

```
MYCHANNEL=external-ca-channel
LABELNAME=privatev2
SEQNUMBER=1
MVERSION=1.0
GOPATH=/opt/gopath
CHAINCODEAPPPATH=$GOPATH/src/github.com/hyperledger/fabric-samples/asset-transfer-private-data/chaincode-go
ORDERER_CA=/var/crypto/ordererOrganizations/orderer.example.com/msp/tlscacerts/tlsca.orderer.example.com-cert.pem
orderpeer=o1.orderer.example.com:7050

peer lifecycle chaincode package $LABELNAME.tar.gz --path $CHAINCODEAPPPATH --lang golang --label $LABELNAME

peer lifecycle chaincode install $LABELNAME.tar.gz
peer lifecycle chaincode queryinstalled

# please replace with query result
CC_PACKAGE_ID=privatev2:763e727f3778b3a8164783442f986eb18d1fe08c15e6efdae7584d1388df08ee

peer lifecycle chaincode approveformyorg -o $orderpeer \
--channelID $MYCHANNEL --name $LABELNAME --version $MVERSION \
--collections-config $CHAINCODEAPPPATH/collections_config.json \
--signature-policy 'OR("Org1MSP.member","Org2MSP.member")' \
--package-id $CC_PACKAGE_ID --sequence $SEQNUMBER --tls --cafile $ORDERER_CA

peer lifecycle chaincode checkcommitreadiness \
--channelID $MYCHANNEL --name $LABELNAME --version $MVERSION \
--collections-config $CHAINCODEAPPPATH/collections_config.json \
--signature-policy 'OR("Org1MSP.member","Org2MSP.member")' \
--sequence $SEQNUMBER \
--tls true --cafile $ORDERER_CA --output json

peer lifecycle chaincode commit -o $orderpeer \
--channelID $MYCHANNEL --name $LABELNAME --version $MVERSION \
--sequence $SEQNUMBER --collections-config $CHAINCODEAPPPATH/collections_config.json \
--signature-policy 'OR("Org1MSP.member","Org2MSP.member")' \
--tls --cafile $ORDERER_CA \
--peerAddresses peer0.org1.example.com:7051 \
--tlsRootCertFiles /var/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
--peerAddresses peer0.org2.example.com:7051 \
--tlsRootCertFiles /var/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
```

## invoke data
Encode data
```
ASSET_PROPERTIES=$(echo -n "{\"objectType\":\"asset\",\"assetID\":\"asset1\",\"color\":\"green\",\"size\":20,\"appraisedValue\":100}" | base64 | tr -d \\n)
echo $ASSET_PROPERTIES
```

建立assets
```
peer chaincode invoke --tls --cafile $ORDERER_CA -C $MYCHANNEL -n $LABELNAME -c "{\"function\":\"CreateAsset\",\"Args\":[]}" --transient "{\"asset_properties\":\"$ASSET_PROPERTIES\"}"
```

查詢private data - allow Org1 & Org2 both
```
peer chaincode query -C $MYCHANNEL -n $LABELNAME -c \
'{"function":"ReadAsset","Args":["asset1"]}'
```

查詢 private data - only Org1
```
peer chaincode query -C $MYCHANNEL -n $LABELNAME -c '{"function":"ReadAssetPrivateDetails","Args":["Org1MSPPrivateCollection","asset1"]}'
```

轉移assets
Org2 將會出價購買assets. 現在asset1設定的價格是100. 測試使用不足一百的價格設定購買
```
ASSET_VALUE=$(echo -n "{\"assetID\":\"asset1\",\"appraisedValue\":99}" | base64 | tr -d \\n)
echo $ASSET_VALUE
peer chaincode invoke -o $orderpeer --tls --cafile $ORDERER_CA -C $MYCHANNEL -n $LABELNAME -c "{\"function\":\"AgreeToTransfer\",\"Args\":[]}" --transient "{\"asset_value\":\"$ASSET_VALUE\"}"
```

查詢提供的購買價格 - only Org2 可以查.
```
peer chaincode query -o $orderpeer --tls --cafile $ORDERER_CA -C $MYCHANNEL -n $LABELNAME -c '{"function":"ReadAssetPrivateDetails","Args":["Org2MSPPrivateCollection","asset1"]}'
```

拿取轉移的buyer列表. 看到有誰購買 但是看不到他的價格
```
peer chaincode query -o $orderpeer --tls --cafile $ORDERER_CA -C $MYCHANNEL -n $LABELNAME -c  '{"function":"ReadTransferAgreement","Args":["asset1"]}'
```

嘗試轉移
```
PEERADDR=peer0.org1.example.com:7051
ORG1ROOTCA=/var/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt

ASSET_OWNER=$(echo -n "{\"assetID\":\"asset1\",\"buyerMSP\":\"Org2MSP\"}" | base64 | tr -d \\n)

peer chaincode invoke -o $orderpeer --tls --cafile $ORDERER_CA -C $MYCHANNEL -n $LABELNAME -c "{\"function\":\"TransferAsset\",\"Args\":[]}" --transient "{\"asset_owner\":\"$ASSET_OWNER\"}" --peerAddresses $PEERADDR --tlsRootCertFiles $ORG1ROOTCA
```

=> 執行失敗 因為金額跟設定價格不符


Org2 將會出價購買assets. 現在asset1設定的價格是100.
```
ASSET_VALUE=$(echo -n "{\"assetID\":\"asset1\",\"appraisedValue\":100}" | base64 | tr -d \\n)
peer chaincode invoke -o $orderpeer --tls --cafile $ORDERER_CA -C $MYCHANNEL -n $LABELNAME -c "{\"function\":\"AgreeToTransfer\",\"Args\":[]}" --transient "{\"asset_value\":\"$ASSET_VALUE\"}"
```


轉移擁有者給Org2MSP.
```
ASSET_OWNER=$(echo -n "{\"assetID\":\"asset1\",\"buyerMSP\":\"Org2MSP\"}" | base64 | tr -d \\n)

peer chaincode invoke -o $orderpeer --tls --cafile $ORDERER_CA -C $MYCHANNEL -n $LABELNAME -c "{\"function\":\"TransferAsset\",\"Args\":[]}" --transient "{\"asset_owner\":\"$ASSET_OWNER\"}" --peerAddresses $PEERADDR --tlsRootCertFiles $ORG1ROOTCA
```

在查詢一次發現已經轉移給Org2了
```
peer chaincode query -C $MYCHANNEL -n $LABELNAME -c "{\"function\":\"ReadAsset\",\"Args\":[\"asset1\"]}"
```
