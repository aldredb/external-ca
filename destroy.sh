#/bin/sh

echo "Destroying all components.."

docker-compose down

docker rm -f $(docker ps -a | grep chaincode1 | awk '{print $1}')

rm -rf config/*.tx config/*.block config/*.json crypto-config identity-rca tls-rca
rm -rf ca-config/msp ca-config/*.db ca-config/IssuerPublicKey ca-config/IssuerRevocationPublicKey
rm -rf ca-config/tlsca/msp ca-config/tlsca/*.db ca-config/tlsca/IssuerPublicKey ca-config/tlsca/IssuerRevocationPublicKey

echo "Done!!"