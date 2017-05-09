#!/bin/sh

EXPECTED_ARGS=1
E_BADARGS=65

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage: `basename $0` catalogue_code"
  exit $E_BADARGS
fi

cd $1
echo extract data $1
../bin/extract_all.sh $1
cd ..
echo done