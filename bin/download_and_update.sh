#!/bin/sh

EXPECTED_ARGS=1
E_BADARGS=65

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage: `basename $0` catalogue_code"
  exit $E_BADARGS
fi

cd $1
echo download data $1
../bin/wget_category.sh $1
echo extract data $1
../bin/extract_all.sh $1
echo reupload files $1
./reupload_files.sh
rm *.svg
rm *.xls
rm *.pdf
rm reupload_files.sh
rm upload_files_and_descriptions.sh
cd ..
echo done
