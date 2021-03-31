#!/bin/bash

docker rm -f ica.orderer.example.com
rm -rf crypto-config/ordererOrganizations identity-rca/orderer tls-rca/orderer
