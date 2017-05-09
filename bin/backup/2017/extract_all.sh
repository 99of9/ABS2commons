#!/bin/bash

compresscat=$(echo $1 | tr -d '.') 
echo $compresscat



rm files.txt
rm duplicates.txt
rm md5_list.txt
rm plot_batch.sh
rm upload_files_and_descriptions.sh
rm reupload_files.sh
touch files.txt
touch duplicates.txt
touch md5_list.txt
touch plot_batch.sh
touch upload_files_and_descriptions.sh
touch reupload_files.sh
chmod u+x plot_batch.sh
chmod u+x upload_files_and_descriptions.sh
chmod u+x reupload_files.sh


meisubs=$(grep --ignore-case meisubs.nsf downloads_table.html)
if [ $? -eq 1 ]
then
    echo "Database: no meisubs.nsf detected, assume abs@archive.nsf"
    archive="abs@archive.nsf"
else
    echo "Database: meisubs.nsf detected"
    archive="meisubs.nsf";
fi

for f in *.xls
do
    echo "Processing $f"

    i=${f#$compresscat}
    i=${i%.*}
    #i=$(echo ${${f#$compresscat}%".xls"});
    
    echo "Expand table $i"
    ../bin/extract_table_all_columns.pl $archive $compresscat$i 2 11 $1 "$i"
    
    chmod u+x plot_batch.sh
    ./plot_batch.sh
    rm ABS*.txt
done

