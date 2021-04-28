#!/bin/bash


docker rm -f  o1.orderer.example.com o2.orderer.example.com o3.orderer.example.com
rm -rf config/*
rm -f channel-artifacts/*

export FABRIC_CFG_PATH=${PWD}
CHANNELID='external-ca-channel'

sudo chown $USER -R .
configtxgen -profile SampleMultiNodeEtcdRaft -outputBlock ./config/genesis.block -channelID genesis-channel

configtxgen -profile Channel -outputCreateChannelTx ./config/${CHANNELID}.tx \
-channelID ${CHANNELID}

configtxgen -profile Channel -outputAnchorPeersUpdate ./config/channel-artifacts/${CHANNELID}_Org1MSPanchors.tx -channelID ${CHANNELID} -asOrg Org1MSP
#configtxgen -profile Channel -outputAnchorPeersUpdate ./config/channel-artifacts/${CHANNELID}_Org2MSPanchors.tx -channelID ${CHANNELID} -asOrg Org2MSP

docker-compose up -d o1.orderer.example.com o2.orderer.example.com o3.orderer.example.com
