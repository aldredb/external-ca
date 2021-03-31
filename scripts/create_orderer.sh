#!/bin/sh

export SUBJ="/C=TW/ST=Taiwan/L=Taiwan/O=orderer.example.com/CN="
export CSR_NAMES="C=TW,ST=Taiwan,L=Taiwan,O=orderer.example.com"
export CHANNEL_NAME="orderer-channel"

ORG_DIR=$PWD/crypto-config/ordererOrganizations/orderer.example.com
PEER_DIR=$ORG_DIR/orderers/$O
IDENTITY_REGISTRAR_DIR=$ORG_DIR/users/admin
TLS_REGISTRAR_DIR=$ORG_DIR/users/tlsadmin
ADMIN_DIR=$ORG_DIR/users/Admin@orderer.example.com
mkdir -p $ORG_DIR/ca $ORG_DIR/tlsca $ORG_DIR/msp $PEER_DIR \
$IDENTITY_REGISTRAR_DIR $TLS_REGISTRAR_DIR $ADMIN_DIR

identityRCA=./identity-rca/orderer
mkdir -p $identityRCA/private $identityRCA/certs $identityRCA/newcerts \
$identityRCA/crl

touch $identityRCA/index.txt $identityRCA/serial $identityRCA/index.txt.attr
echo 1000 > $identityRCA/serial
echo 1000 > $identityRCA/crlnumber
tree $identityRCA

openssl ecparam -name prime256v1 -genkey -noout \
-out $identityRCA/private/rca.identity.orderer.example.com.key

cat /etc/ssl/openssl.cnf | sed "s/RANDFILE\s*=\s*\$ENV::HOME\/\.rnd/#/" > rnd_openssl.cnf

openssl req -config openssl_root-orderer_identity.cnf -new -x509 -sha256 -extensions v3_ca \
-key $identityRCA/private/rca.identity.orderer.example.com.key -out \
$identityRCA/certs/rca.identity.orderer.example.com.cert -days 3650 -subj \
"${SUBJ}rca.identity.orderer.example.com" #-config rnd_openssl.cnf

openssl ecparam -name prime256v1 -genkey -noout -out \
$ORG_DIR/ca/ica.identity.orderer.example.com.key

openssl req -new -sha256 -key $ORG_DIR/ca/ica.identity.orderer.example.com.key \
-out $ORG_DIR/ca/ica.identity.orderer.example.com.csr \
-subj "${SUBJ}ica.identity.orderer.example.com" \
-config openssl_root-orderer_identity.cnf
#-config rnd_openssl.cnf

openssl ca -batch -config openssl_root-orderer_identity.cnf -extensions \
v3_intermediate_ca -days 1825 -notext -md sha256 \
-in $ORG_DIR/ca/ica.identity.orderer.example.com.csr \
-out $ORG_DIR/ca/ica.identity.orderer.example.com.cert

cat $ORG_DIR/ca/ica.identity.orderer.example.com.cert \
$identityRCA/certs/rca.identity.orderer.example.com.cert \
> $ORG_DIR/ca/chain.identity.orderer.example.com.cert


export tlsRCA=./tls-rca/orderer

mkdir -p $tlsRCA/private $tlsRCA/certs $tlsRCA/newcerts $tlsRCA/crl
touch $tlsRCA/index.txt $tlsRCA/serial $tlsRCA/index.txt.attr
echo 1000 > $tlsRCA/serial
echo 1000 > $tlsRCA/crlnumber
tree $tlsRCA

openssl ecparam -name prime256v1 -genkey -noout -out \
$tlsRCA/private/rca.tls.orderer.example.com.key

openssl req -config openssl_root-orderer_tls.cnf -new -x509 -sha256 \
-extensions v3_ca \
-key $tlsRCA/private/rca.tls.orderer.example.com.key \
-out $tlsRCA/certs/rca.tls.orderer.example.com.cert -days 3650 -subj \
"${SUBJ}rca.tls.orderer.example.com"

openssl ecparam -name prime256v1 -genkey -noout -out \
$ORG_DIR/tlsca/ica.tls.orderer.example.com.key


openssl req -new -sha256 -key $ORG_DIR/tlsca/ica.tls.orderer.example.com.key -out \
$ORG_DIR/tlsca/ica.tls.orderer.example.com.csr \
-subj "${SUBJ}ica.tls.orderer.example.com" \
-config openssl_root-orderer_tls.cnf
#-config rnd_openssl.cnf

openssl ca -batch -config openssl_root-orderer_tls.cnf \
-extensions v3_intermediate_ca \
-days 1825 -notext -md sha256 -in $ORG_DIR/tlsca/ica.tls.orderer.example.com.csr \
-out $ORG_DIR/tlsca/ica.tls.orderer.example.com.cert


cat $ORG_DIR/tlsca/ica.tls.orderer.example.com.cert $tlsRCA/certs/rca.tls.orderer.example.com.cert > $ORG_DIR/tlsca/chain.tls.orderer.example.com.cert

cat $ORG_DIR/tlsca/chain.tls.orderer.example.com.cert


openssl ec -in $ORG_DIR/ca/ica.identity.orderer.example.com.key -text > $ORG_DIR/ca/ica.identity.orderer.example.com.key.pem
openssl ec -in $ORG_DIR/tlsca/ica.tls.orderer.example.com.key -text > $ORG_DIR/tlsca/ica.tls.orderer.example.com.key.pem
