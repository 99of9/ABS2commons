if [ $# -ne 1 ]
then
    echo "Usage - $0 3401.0 (catalogue num)"
    exit 1
fi

echo -n "wget -r -l 1 -nd -R \"*zip*\",\"*srd*\",png,jpg,gif,opendocument,1,css,online,help,Help,Website,txt,js http://www.abs.gov.au" > wget_line.sh
grep -m1 Downloads $1 |cut -d "\"" -f 6 >> wget_line.sh
chmod u+x wget_line.sh
