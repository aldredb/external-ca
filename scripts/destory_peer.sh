#!/bin/bash

docker rm -f ica.org1.example.com
rm -rf crypto-config/peerOrganizations identity-rca/* tls-rca/*
