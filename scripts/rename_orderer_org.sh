CURRENTORGDOMAIN=orderer.mydomain.com
CURRENTORGMSPNAME=Orderer

REPLACEORGDOMAIN=orderer.mydomain.com
REPLACEORGMSPNAME=Orderer

find ./ ! -iname 'rename*.sh' -type f \( -iname \*.yaml -o -iname \*.sh -o -iname \*.cnf \) -exec sed -i '' -e "s/$CURRENTORGDOMAIN/$REPLACEORGDOMAIN/g" {} \;
find ./ ! -iname 'rename*.sh' -type f \( -iname \*.yaml -o -iname \*.sh -o -iname \*.cnf \) -exec sed -i '' -e "s/$CURRENTORGDOMAIN/$REPLACEORGMSPNAME/g" {} \;
