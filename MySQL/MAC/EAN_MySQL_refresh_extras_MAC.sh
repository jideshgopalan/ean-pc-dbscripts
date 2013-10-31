#!/bin/bash
#########################################################################
## Process Extra files from other public sources                       ##
## Process tested in MAC OS Mountain Lion                              ##
## other than the default of the instalation you will need to install: ##
## -> MAMP regular distribution and defaults.                          ##
#########################################################################
# Modified for MAC
### Environment ###
STARTTIME=$(date +%s)
## for Linux: MYSQL_DIR=/usr/bin/
MYSQL_DIR=/Applications/MAMP/Library/bin/
# for simplicity I added the MYSQL bin path to the Windows 
# path environment variable, for Windows set it to ""
#MYSQL_DIR=""
#MySQL user, password, host (Server)
MYSQL_USER=root
MYSQL_PASS=root
#using a number will force it to use TCP/IP if no a pipe connection
MYSQL_HOST=127.0.0.1
MYSQL_DB=eanextras
MYSQL_PORT=8889
MYSQL_PROTOCOL=TCP
# home directory of the user (in our case "/home/eanuser")
HOME_DIR=/Users/jarce
## directory under HOME_DIR
FILES_DIR=eanextras
## directory under HOME_DIR
BACKUP_DIR=eanextrasback
### Import files ###
############################################
# the list should match the tables        ##
# created by create_ean_extras.sql script ##
############################################
FILES=(
airports
countries
regions
)

## home where the process will execute
## this will be CRONed so it needs the working directory absolute path
## change to your user home directory
cd ${HOME_DIR}

echo "Starting at working directory..."
pwd
## create subdirectory if required
if [ ! -d ${FILES_DIR} ]; then
   echo "creating download files directory..."
   mkdir ${FILES_DIR}
fi

## all clear, move into the working directory
cd ${FILES_DIR}

### Download Data ###
echo "Downloading files using wget..."
for FILE in ${FILES[@]}
do
#   wget  -t 30 --no-check-certificate -nd http://www.ourairports.com/data/$FILE.csv
    ## download the files via HTTP (no need for https)
    wget  -t 30 --no-verbose http://www.ourairports.com/data/$FILE.csv
    ## rename files to CamelCase format
    mv `echo $FILE | tr \[A-Z\] \[a-z\]`.csv $FILE.txt
done
echo "downloading files done."


### Update MySQL Data ###
### Parameters that you may need:
### If you use LOW_PRIORITY, execution of the LOAD DATA statement is delayed until no other clients are reading from the table.
CMD_MYSQL="${MYSQL_DIR}mysql  --local-infile=1 --default-character-set=utf8 --protocol=${MYSQL_PROTOCOL} --port=${MYSQL_PORT} --user=${MYSQL_USER} --pass=${MYSQL_PASS} --host=${MYSQL_HOST} --database=${MYSQL_DB}"
echo "Uploading Data to MySQL..."

for FILE in ${FILES[@]}
do
   ## table name are lowercase
   tablename=`echo $FILE | tr "[[:upper:]]" "[[:lower:]]"`
   echo "Uploading ($FILE) to ($MYSQL_DB.$tablename) with REPLACE option..."
   ## erase all previous data first
   ## $CMD_MYSQL --execute="TRUNCATE TABLE $FILE;"
   ## let's try with the REPLACE OPTION
   $CMD_MYSQL --execute="LOAD DATA LOCAL INFILE '$FILE.txt' REPLACE INTO TABLE $tablename CHARACTER SET utf8 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES;"
   ## we need to erase the records, NOT updated today
   echo "erasing old records from ($tablename)..."
   $CMD_MYSQL --execute="DELETE FROM $tablename WHERE datediff(TimeStamp, now()) < 0;"
done
echo "Upload done."

## openflights Airports data
echo -e "\n"
tablename="openflightsairports"
echo "Downloading and unzipping (Openflights Airports)..."
## wget  -t 30 --no-verbose -r -N -nd http://openflights.svn.sourceforge.net/viewvc/openflights/openflights/data/airports.dat
wget  -t 30 --no-verbose -r -N -nd http://sourceforge.net/p/openflights/code/757/tree/openflights/data/airports.dat?format=raw
mv -f airports.dat* openflightsairports.txt
echo "Uploading (Openflights Airports) to ($MYSQL_DB.$tablename) with REPLACE option..."
$CMD_MYSQL --execute="LOAD DATA LOCAL INFILE '$tablename.txt' REPLACE INTO TABLE $tablename CHARACTER SET utf8 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"';"
## we need to erase the records, NOT updated today
echo "erasing old records from ($tablename)..."
$CMD_MYSQL --execute="DELETE FROM $tablename WHERE datediff(TimeStamp, now()) < 0;"


### DOWNLOAD SPECIAL FILES SECTIONS
echo -e "\n"
tablename="propertyidcrossreference"
echo "Downloading and unzipping (PropertyID Cross Reference Report)..."
wget  -t 30 --no-verbose -r -N -nd http://www.ian.com/affiliatecenter/include/PropertyID_Cross_Reference_Report.zip
unzip -L -o PropertyID_Cross_Reference_Report.zip
mv -f propertyid*.csv propertyidcrossreference.txt
echo "Uploading (propertyid cross reference report) to ($MYSQL_DB.$tablename) with REPLACE option..."
$CMD_MYSQL --execute="LOAD DATA LOCAL INFILE '$tablename.txt' REPLACE INTO TABLE $tablename CHARACTER SET utf8 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES;"
## we need to erase the records, NOT updated today
echo "erasing old records from ($tablename)..."
$CMD_MYSQL --execute="DELETE FROM $tablename WHERE datediff(TimeStamp, now()) < 0;"

echo -e "\n"
tablename="propertysuppliermapping"
echo "Downloading and unzipping (Property Supplier Mapping)..."
wget  -t 30 --no-verbose -r -N -nd http://www.ian.com/affiliatecenter/include/V2/PropertySupplierMapping.zip
unzip -L -o PropertySupplierMapping.zip
if [ -f PropertySupplierMapping.txt ]
then
   echo "renaming to lowercase"
   mv -f PropertySupplierMapping.txt propertysuppliermapping.txt
fi
## file is (CR) only - like OLD MAC txt files, convert to Unix
echo "Cleaning up ($tablename.txt)..."
dos2unix -c mac propertysuppliermapping.txt
echo "Uploading (property supplier mapping) to ($MYSQL_DB.$tablename) with REPLACE option..."
$CMD_MYSQL --execute="LOAD DATA LOCAL INFILE '$tablename.txt' REPLACE INTO TABLE $tablename CHARACTER SET utf8 FIELDS TERMINATED BY ',' IGNORE 1 LINES;"
echo "erasing old records from ($tablename)..."
$CMD_MYSQL --execute="DELETE FROM $tablename WHERE datediff(TimeStamp, now()) < 0;"

echo -e "\n"
tablename="destinationids"
echo "Downloading and unzipping (Destination IDs)..."
wget  -t 30 --no-verbose -r -N -nd http://www.ian.com/affiliatecenter/include/Destination_Detail.zip
unzip -L -o Destination_Detail.zip
### the files are named with the dates, so let's rename it
mv -f destination_detail*.txt destinationids.txt
echo "Uploading ($tablename.txt) to ($MYSQL_DB.$tablename) with REPLACE option..."
$CMD_MYSQL --execute="LOAD DATA LOCAL INFILE '$tablename.txt' REPLACE INTO TABLE $tablename CHARACTER SET utf8 FIELDS TERMINATED BY '|' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES;"
## we need to erase the records, NOT updated today
echo "erasing old records from ($tablename)..."
$CMD_MYSQL --execute="DELETE FROM $tablename WHERE datediff(TimeStamp, now()) < 0;"

echo -e "\n"
tablename="landmark"
echo "Downloading and unzipping (Landmarks IDs)..."
wget  -t 30 --no-verbose -r -N -nd https://www.ian.com/affiliatecenter/include/Landmark.zip
unzip -L -o Landmark.zip
echo "Uploading ($tablename.txt) to ($MYSQL_DB.$tablename) with REPLACE option..."
$CMD_MYSQL --execute="LOAD DATA LOCAL INFILE '$tablename.txt' REPLACE INTO TABLE $tablename CHARACTER SET utf8 FIELDS TERMINATED BY '|' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES;"
## we need to erase the records, NOT updated today
echo "erasing old records from ($tablename)..."
$CMD_MYSQL --execute="DELETE FROM $tablename WHERE datediff(TimeStamp, now()) < 0;"

echo -e "\n"
tablename="expediaactive"
echo "Downloading and unzipping (Expedia All Active)..."
wget  -t 30 --no-verbose -r -N -nd http://www.ian.com/affiliatecenter/include/Hotel_All_Active.zip
unzip -L -o Hotel_All_Active.zip
### the files are named with the dates, so let's rename it
mv -f hotel_all_active*.txt expediaactive.txt
## needed to strip out some strange characters
echo "Cleaning up ($tablename.txt)..."
dos2unix expediaactive.txt
echo "Uploading ($tablename.txt) to ($MYSQL_DB.$tablename) with REPLACE option..."
$CMD_MYSQL --execute="LOAD DATA LOCAL INFILE '$tablename.txt' REPLACE INTO TABLE $tablename CHARACTER SET utf8 FIELDS TERMINATED BY '|' IGNORE 1 LINES;"
## we need to erase the records, NOT updated today
echo "erasing old records from ($tablename)..."
$CMD_MYSQL --execute="DELETE FROM $tablename WHERE datediff(TimeStamp, now()) < 0;"

echo -e "\n"
tablename="venereactive"
echo "Downloading and unzipping (Venere Active)..."
wget  -t 30 --no-verbose -r -N -nd http://www.ian.com/affiliatecenter/include/Venere_Active.zip
unzip -L -o Venere_active.zip
### the files are named with the dates, so let's rename it
#mv -f venere_active*.txt venereactive.txt
## needed to strip out some strange characters
echo "Cleaning up ($tablename.txt)..."
#dos2unix venereactive.txt
#this command will let pass:
#octal 11: tab, octal 12: linefeed, octal 15: carriage return
#octal 40 through octal 176: all the "good" keyboard characters
#but we extend it to Octal 251 (Ascii 169) so it will include the accented characters
tr -cd "\11\12\15\40-\251" < venere_active*.txt > venereactive.txt
#tr -cd "[:print:]" < venere_active*.txt > venereactive.txt
rm venere_active*.txt
echo "Uploading ($tablename.txt) to ($MYSQL_DB.$tablename) with REPLACE option..."
$CMD_MYSQL --execute="LOAD DATA LOCAL INFILE '$tablename.txt' REPLACE INTO TABLE $tablename CHARACTER SET utf8 FIELDS TERMINATED BY '|' IGNORE 1 LINES;"
## we need to erase the records, NOT updated today
echo "erasing old records from ($tablename)..."
$CMD_MYSQL --execute="DELETE FROM $tablename WHERE datediff(TimeStamp, now()) < 0;"

echo -e "\n"
tablename="veneredescription"
echo "Downloading and unzipping (Venere Descriptions)..."
wget  -t 30 --no-verbose -r -N -nd http://www.ian.com/affiliatecenter/include/Venere_description.zip
unzip -L -o Venere_description.zip
### the files are named with the dates, so let's rename it
#mv -f venere_description*.txt veneredescription.txt
## needed to strip out some strange characters
echo "Cleaning up ($tablename.txt)..."
tr -cd "\11\12\15\40-\251" < venere_description*.txt > veneredescription.txt
rm venere_description*.txt
#dos2unix veneredescription.txt
echo "Uploading ($tablename.txt) to ($MYSQL_DB.$tablename) with REPLACE option..."
$CMD_MYSQL --execute="LOAD DATA LOCAL INFILE '$tablename.txt' REPLACE INTO TABLE $tablename CHARACTER SET utf8 FIELDS TERMINATED BY '|' IGNORE 1 LINES;"
## we need to erase the records, NOT updated today
echo "erasing old records from ($tablename)..."
$CMD_MYSQL --execute="DELETE FROM $tablename WHERE datediff(TimeStamp, now()) < 0;"

echo -e "\n"
tablename="vacationrentalsactive"
echo "Downloading and unzipping (Vacation Rentals/Condo All Active)..."
wget  -t 30 --no-verbose -r -N -nd http://www.ian.com/affiliatecenter/include/Condo_All_Active.zip
unzip -L -o Condo_All_Active.zip
### the files are named with the dates, so let's rename it
mv -f condo_all_active*.txt vacationrentalsactive.txt
## needed to strip out some strange characters
echo "Cleaning up ($tablename.txt)..."
dos2unix vacationrentalsactive.txt
echo "Uploading ($tablename.txt) to ($MYSQL_DB.$tablename) with REPLACE option..."
$CMD_MYSQL --execute="LOAD DATA LOCAL INFILE '$tablename.txt' REPLACE INTO TABLE $tablename CHARACTER SET utf8 FIELDS TERMINATED BY '|' IGNORE 1 LINES;"
## we need to erase the records, NOT updated today
echo "erasing old records from ($tablename)..."
$CMD_MYSQL --execute="DELETE FROM $tablename WHERE datediff(TimeStamp, now()) < 0;"



## geonames from http://geonames.org
echo -e "\n"
tablename="geonames"
echo "Downloading and unzipping (allCountries from geonames.org)..."
wget  -t 30 --no-verbose -r -N -nd http://download.geonames.org/export/dump/allCountries.zip
unzip -L -o allCountries.zip
mv -f allcountries.txt geonames.txt
echo "Uploading (allCountries) to ($MYSQL_DB.$tablename) with REPLACE option..."
$CMD_MYSQL --execute="LOAD DATA LOCAL INFILE '$tablename.txt' REPLACE INTO TABLE $tablename CHARACTER SET utf8 FIELDS TERMINATED BY '\t';"
## we need to erase the records, NOT updated today
echo "erasing old records from ($tablename)..."
$CMD_MYSQL --execute="DELETE FROM $tablename WHERE datediff(TimeStamp, now()) < 0;"

echo -e "\n"
echo "Verify database against files..."
### Verify entries in tables against files ###
CMD_MYSQL="${MYSQL_DIR}mysqlshow --count ${MYSQL_DB} --protocol=${MYSQL_PROTOCOL} --port=${MYSQL_PORT} --user=${MYSQL_USER} --pass=${MYSQL_PASS} --host=${MYSQL_HOST}"
$CMD_MYSQL

FILES=(
airports
countries
regions
openflightsairports
propertyidcrossreference
propertysuppliermapping
destinationids
landmark
expediaactive
vacationrentalsactive
venereactive
veneredescription
geonames
)

### find the amount of records per datafile
### should match to the amount of database records
echo "+---------------------------------+----------+------------+"
echo "|             File                |       Records         |"
echo "+---------------------------------+----------+------------+"
for FILE in ${FILES[@]}
do
   ## records=`head --lines=-1 $FILE.txt | wc -l`
   ## To count the number of output records minus the header
   records=$(($(wc -l $FILE.txt | awk '{print $1}')-1))
   { printf "|" && printf "%33s" $FILE && printf "|" && printf "%23d" $records && printf "|\n"; }
done
echo "+---------------------------------+----------+------------+"
echo "Verify done."

echo "script (import_db.sh) done."

## display endtime for the script
ENDTIME=$(date +%s)
secs=$(( $ENDTIME - $STARTTIME ))
h=$(( secs / 3600 ))
m=$(( ( secs / 60 ) % 60 ))
s=$(( secs % 60 ))
printf "total script time: %02d:%02d:%02d\n" $h $m $s
