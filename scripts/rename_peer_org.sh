#!/bin/bash

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGw;;
    *)          machine="UNKNOWN:${unameOut}"
esac

CURRENTORGDOMAIN=org1.example.com
CURRENTORGMSPNAME=Org1

REPLACEORGDOMAIN=org1.newdomain.com
REPLACEORGMSPNAME=NewOrg

echo "Current os: $machine"
if [ $machine = "Linux" ]
  find ./ ! -iname 'rename*.sh' -type f \( -iname \*.yaml -o -iname \*.sh -o -iname \*.cnf \) -exec sed -i "s/$CURRENTORGDOMAIN/$REPLACEORGDOMAIN/g" {} \;
  find ./ ! -iname 'rename*.sh' -type f \( -iname \*.yaml -o -iname \*.sh -o -iname \*.cnf \) -exec sed -i "s/$CURRENTORGDOMAIN/$REPLACEORGMSPNAME/g" {} \;
then
elif [ $machine = "Mac" ]
then
  find ./ ! -iname 'rename*.sh' -type f \( -iname \*.yaml -o -iname \*.sh -o -iname \*.cnf \) -exec sed -i '' -e "s/$CURRENTORGDOMAIN/$REPLACEORGDOMAIN/g" {} \;
  find ./ ! -iname 'rename*.sh' -type f \( -iname \*.yaml -o -iname \*.sh -o -iname \*.cnf \) -exec sed -i '' -e "s/$CURRENTORGDOMAIN/$REPLACEORGMSPNAME/g" {} \;
else
  echo "$machine is unsupported!"
fi
