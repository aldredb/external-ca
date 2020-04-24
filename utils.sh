#!/bin/bash

if ! [ -x "$(command -v jq)" ]; then
  echo 'Error: jq is not installed.' >&2
  exit 1
fi

echo "Good to Go!!"

function retrieve_current_config()
{   
    BASE_DOWNLOAD_PATH=/config
    WORKING_DIR=$BASE_DOWNLOAD_PATH/$2_$1
    CHANNEL=$2
    MSPID=$3
    MSPPATH=$4
    ORDERER=$5
    ORDERER_TLS_CERT=$6

    echo "Retrieve $CHANNEL latest config block.."

    docker exec -e "WORKING_DIR=$WORKING_DIR" cli sh -c 'mkdir $WORKING_DIR'

    docker exec -e "WORKING_DIR=$WORKING_DIR" \
                -e "CORE_PEER_LOCALMSPID=$MSPID" \
                -e "CORE_PEER_MSPCONFIGPATH=$MSPPATH" \
                -e "ORDERER=$ORDERER" \
                -e "CORE_PEER_TLS_ROOTCERT_FILE=$ORDERER_TLS_CERT" \
                -e "CHANNEL=$CHANNEL" cli \
                sh -c 'peer channel fetch config $WORKING_DIR/current_config.pb -o $ORDERER --tls --cafile $CORE_PEER_TLS_ROOTCERT_FILE -c $CHANNEL'

    echo "Convert the config block into JSON format.."
    docker exec -e "WORKING_DIR=$WORKING_DIR" cli sh -c 'configtxlator proto_decode --input $WORKING_DIR/current_config.pb --type common.Block --output $WORKING_DIR/current_config_block.json'

    echo "Stripping headers.."
    docker exec -e "WORKING_DIR=$WORKING_DIR" cli sh -c 'jq .data.data[0].payload.data.config $WORKING_DIR/current_config_block.json > $WORKING_DIR/current_config.json'
}

function prepare_unsigned_modified_config()
{
    BASE_DOWNLOAD_PATH=/config
    WORKING_DIR=$BASE_DOWNLOAD_PATH/$2_$1
    CHANNEL=$2

    echo "Preparing unsigned protobuf update.."

    echo "Step 1/6"
    docker exec -e "WORKING_DIR=$WORKING_DIR" cli sh -c 'configtxlator proto_encode --input $WORKING_DIR/current_config.json --type common.Config --output $WORKING_DIR/current_config.pb'

    echo "Step 2/6"
    docker exec -e "WORKING_DIR=$WORKING_DIR" cli sh -c 'configtxlator proto_encode --input $WORKING_DIR/modified_config.json --type common.Config --output $WORKING_DIR/modified_config.pb'

    echo "Step 3/6"
    docker exec -e "WORKING_DIR=$WORKING_DIR" -e "CHANNEL=$CHANNEL" cli sh -c 'configtxlator compute_update --channel_id $CHANNEL --original $WORKING_DIR/current_config.pb --updated $WORKING_DIR/modified_config.pb --output $WORKING_DIR/config_update.pb'

    echo "Step 4/6"
    docker exec -e "WORKING_DIR=$WORKING_DIR" cli sh -c 'configtxlator proto_decode --input $WORKING_DIR/config_update.pb --type common.ConfigUpdate  --output $WORKING_DIR/config_update.json'

    echo "Step 5/6"
    docker exec -e "WORKING_DIR=$WORKING_DIR" -e "CHANNEL=$CHANNEL" cli sh -c 'echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"$CHANNEL\", \"type\":2}},\"data\":{\"config_update\":"$(cat $WORKING_DIR/config_update.json)"}}}" | jq . > $WORKING_DIR/config_update_in_envelope.json'

    echo "Step 6/6"
    docker exec -e "WORKING_DIR=$WORKING_DIR" cli sh -c 'configtxlator proto_encode --input $WORKING_DIR/config_update_in_envelope.json --type common.Envelope --output $WORKING_DIR/config_update_in_envelope.pb'
}

function sign_config_update()
{   
    BASE_DOWNLOAD_PATH=/config
    WORKING_DIR=$BASE_DOWNLOAD_PATH/$2_$1
    CHANNEL=$2
    MSPID=$3
    MSPPATH=$4

    echo "Signing config update as $MSPPATH from $MSPID.."
    docker exec -e "WORKING_DIR=$WORKING_DIR" \
                -e "CORE_PEER_LOCALMSPID=$MSPID" \
                -e "CORE_PEER_MSPCONFIGPATH=$MSPPATH" cli \
                sh -c 'peer channel signconfigtx -f $WORKING_DIR/config_update_in_envelope.pb'
}

function send_config_update()
{
    BASE_DOWNLOAD_PATH=/config
    WORKING_DIR=$BASE_DOWNLOAD_PATH/$2_$1
    CHANNEL=$2
    MSPID=$3
    MSPPATH=$4
    ORDERER=$5
    ORDERER_TLS_CERT=$6

    echo "Sending config update as $MSPATH from $MSPID.."
    docker exec -e "WORKING_DIR=$WORKING_DIR" \
                -e "CORE_PEER_LOCALMSPID=$MSPID" \
                -e "CORE_PEER_MSPCONFIGPATH=$MSPPATH" \
                -e "ORDERER=$ORDERER" \
                -e "CORE_PEER_TLS_ROOTCERT_FILE=$ORDERER_TLS_CERT" \
                -e "CHANNEL=$CHANNEL" cli \
                sh -c 'peer channel update -f $WORKING_DIR/config_update_in_envelope.pb -o $ORDERER --tls --cafile $CORE_PEER_TLS_ROOTCERT_FILE -c $CHANNEL'
}

function retrieve_updated_config()
{   
    BASE_DOWNLOAD_PATH=/config
    WORKING_DIR=$BASE_DOWNLOAD_PATH/$2_$1
    CHANNEL=$2
    MSPID=$3
    MSPPATH=$4
    ORDERER=$5
    ORDERER_TLS_CERT=$6

    echo "Retrieve $CHANNEL latest config block.."

    docker exec -e "WORKING_DIR=$WORKING_DIR" \
                -e "CORE_PEER_LOCALMSPID=$MSPID" \
                -e "CORE_PEER_MSPCONFIGPATH=$MSPPATH" \
                -e "ORDERER=$ORDERER" \
                -e "CORE_PEER_TLS_ROOTCERT_FILE=$ORDERER_TLS_CERT" \
                -e "CHANNEL=$CHANNEL" cli \
                sh -c 'peer channel fetch config $WORKING_DIR/updated_config.pb -o $ORDERER --tls --cafile $CORE_PEER_TLS_ROOTCERT_FILE -c $CHANNEL'

    echo "Convert the config block into JSON format.."
    docker exec -e "WORKING_DIR=$WORKING_DIR" cli sh -c 'configtxlator proto_decode --input $WORKING_DIR/updated_config.pb --type common.Block --output $WORKING_DIR/updated_config_block.json'

    echo "Stripping headers.."
    docker exec -e "WORKING_DIR=$WORKING_DIR" cli sh -c 'jq .data.data[0].payload.data.config $WORKING_DIR/updated_config_block.json > $WORKING_DIR/updated_config.json'
}