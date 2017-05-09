if [ $# -ne 1 ]
then
    echo "Usage - $0 3401.0 (catalogue num)"
    exit 1
fi

#e.g. parameters: ./wget_category.sh Feb 2012
echo download catalogue: $1

#get landing page
wget http://www.abs.gov.au/ausstats/abs@.nsf/mf/$1 -O $1
../bin/proc_landing.sh $1

#get files
./wget_line.sh

mv $1???\ ????\?OpenDocument downloads_table.html
rm *OpenDocument
rm second*
rm SearchProduct*
rm robots*txt

rm move_log.sh
touch move_log.sh
#rename files
#with date ... if you want to keep all dated versions of the excel files
#for i in lo*; do j=`echo $i | cut -d "&" -f 2`; k=`echo $i | cut -d "&" -f 8` ; echo "cp \"$i\" $j"_"$k".xls"" >> move_log.sh; done
#without date
for i in lo*; do j=`echo $i | cut -d "&" -f 2 | sed -e 's/ /_/g'`; k=`echo $i | cut -d "&" -f 8` ; echo "mv \"$i\" \"$j\"" >> move_log.sh; done

chmod u+x move_log.sh
./move_log.sh
