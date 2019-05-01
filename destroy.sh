#/bin/sh

echo "Destroying all components.."

docker-compose down

docker rm -f $(docker ps -a | grep chaincode1 | awk '{print $1}')

rm -rf config/*.tx config/*.block config/*.json crypto-config rca
rm -rf ca-config/msp ca-config/*.db ca-config/IssuerPublicKey ca-config/IssuerRevocationPublicKey

echo "Done!!"