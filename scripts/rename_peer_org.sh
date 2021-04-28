CURRENTORGDOMAIN=org1.example.com
CURRENTORGMSPNAME=Org1

REPLACEORGDOMAIN=org1.newdomain.com
REPLACEORGMSPNAME=NewOrg

find ./ ! -iname 'rename*.sh' -type f \( -iname \*.yaml -o -iname \*.sh -o -iname \*.cnf \) -exec sed -i '' -e "s/$CURRENTORGDOMAIN/$REPLACEORGDOMAIN/g" {} \;
find ./ ! -iname 'rename*.sh' -type f \( -iname \*.yaml -o -iname \*.sh -o -iname \*.cnf \) -exec sed -i '' -e "s/$CURRENTORGDOMAIN/$REPLACEORGMSPNAME/g" {} \;
