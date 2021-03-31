#!/bin/sh

SUBJ="/C=TW/ST=Taiwan/L=Taiwan/O=org1.example.com/CN="
CSR_NAMES="C=TW,ST=Taiwan,L=Taiwan,O=org1.example.com"
CHANNEL_NAME="external-ca-channel"

ORG_DIR=$PWD/crypto-config/peerOrganizations/org1.example.com
PEER_DIR=$ORG_DIR/peers/peer0.org1.example.com
IDENTITY_REGISTRAR_DIR=$ORG_DIR/users/admin
TLS_REGISTRAR_DIR=$ORG_DIR/users/tlsadmin
ADMIN_DIR=$ORG_DIR/users/Admin@org1.example.com


mkdir -p $ORG_DIR/ca $ORG_DIR/tlsca $ORG_DIR/msp $PEER_DIR \
$IDENTITY_REGISTRAR_DIR $TLS_REGISTRAR_DIR $ADMIN_DIR

mkdir -p identity-rca/private identity-rca/certs identity-rca/newcerts \
identity-rca/crl

touch identity-rca/index.txt identity-rca/serial identity-rca/index.txt.attr
echo 1000 > identity-rca/serial
echo 1000 > identity-rca/crlnumber
tree identity-rca

openssl ecparam -name prime256v1 -genkey -noout \
-out identity-rca/private/rca.identity.org1.example.com.key

cat /etc/ssl/openssl.cnf | sed "s/RANDFILE\s*=\s*\$ENV::HOME\/\.rnd/#/" > rnd_openssl.cnf

openssl req -config openssl_root-identity.cnf -new -x509 -sha256 -extensions v3_ca \
-key identity-rca/private/rca.identity.org1.example.com.key -out \
identity-rca/certs/rca.identity.org1.example.com.cert -days 3650 -subj \
"${SUBJ}rca.identity.org1.example.com" -config rnd_openssl.cnf

openssl ecparam -name prime256v1 -genkey -noout -out \
$ORG_DIR/ca/ica.identity.org1.example.com.key

openssl req -new -sha256 -key $ORG_DIR/ca/ica.identity.org1.example.com.key \
-out $ORG_DIR/ca/ica.identity.org1.example.com.csr \
-subj "${SUBJ}ica.identity.org1.example.com" \
-config rnd_openssl.cnf

openssl ca -batch -config openssl_root-identity.cnf -extensions \
v3_intermediate_ca -days 1825 -notext -md sha256 \
-in $ORG_DIR/ca/ica.identity.org1.example.com.csr \
-out $ORG_DIR/ca/ica.identity.org1.example.com.cert

cat $ORG_DIR/ca/ica.identity.org1.example.com.cert \
$PWD/identity-rca/certs/rca.identity.org1.example.com.cert \
> $ORG_DIR/ca/chain.identity.org1.example.com.cert

mkdir -p tls-rca/private tls-rca/certs tls-rca/newcerts tls-rca/crl
touch tls-rca/index.txt tls-rca/serial tls-rca/index.txt.attr
echo 1000 > tls-rca/serial
echo 1000 > tls-rca/crlnumber
tree tls-rca

openssl ecparam -name prime256v1 -genkey -noout -out \
tls-rca/private/rca.tls.org1.example.com.key

openssl req -config openssl_root-tls.cnf -new -x509 -sha256 -extensions \
v3_ca -key tls-rca/private/rca.tls.org1.example.com.key \
-out tls-rca/certs/rca.tls.org1.example.com.cert -days 3650 -subj \
"${SUBJ}rca.tls.org1.example.com"

openssl ecparam -name prime256v1 -genkey -noout -out \
$ORG_DIR/tlsca/ica.tls.org1.example.com.key

openssl req -new -sha256 -key $ORG_DIR/tlsca/ica.tls.org1.example.com.key -out \
$ORG_DIR/tlsca/ica.tls.org1.example.com.csr \
-subj "${SUBJ}ica.tls.org1.example.com" \
-config rnd_openssl.cnf

openssl ca -batch -config openssl_root-tls.cnf -extensions v3_intermediate_ca \
-days 1825 -notext -md sha256 -in $ORG_DIR/tlsca/ica.tls.org1.example.com.csr \
-out $ORG_DIR/tlsca/ica.tls.org1.example.com.cert

cat $ORG_DIR/tlsca/ica.tls.org1.example.com.cert $PWD/tls-rca/certs/rca.tls.org1.example.com.cert > $ORG_DIR/tlsca/chain.tls.org1.example.com.cert

cat $ORG_DIR/tlsca/chain.tls.org1.example.com.cert

openssl ec -in $ORG_DIR/ca/ica.identity.org1.example.com.key -text > $ORG_DIR/ca/ica.identity.org1.example.com.key.pem
openssl ec -in $ORG_DIR/tlsca/ica.tls.org1.example.com.key -text > $ORG_DIR/tlsca/ica.tls.org1.example.com.key.pem
