#/bin/sh

echo "Destroying all components.."

docker-compose down

docker rm -f $(docker ps -a | grep chaincode1 | awk '{print $1}')

sudo rm -rf config/* crypto-config identity-rca tls-rca newica
# sudo rm -rf ca-config
# git checkout ca-config

echo "Done!!"
