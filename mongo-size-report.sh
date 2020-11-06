#!/bin/bash

check_mongo_fs_size ()
{

unset SIZE FREE_SPACE
SIZE=`du -sh /var/lib/mongodb/ | awk '{print $1}'`
FREE_SPACE=`df -hPT /var/lib/mongodb/ | awk 'NR>1{print $4}'`

}

echo -e "\n--> Checking whether mongodb service is online or not."

STAT=`systemctl is-active rh-mongodb34-mongod`

if [[ $STAT == 'active' ]]
then

echo -e "  *** Service is online"

echo -e "\n--> What is the engine being used ? "

ENGINE=`cat << EOF | mongo pulp_database | awk -F ':' '/\"name\"/{print $NF}' | tr -d ' ",'
db.serverStatus().storageEngine
EOF
`
echo -e "  *** $ENGINE"

echo -e "\n--> Overall status of db."

cat << EOF | mongo pulp_database | perl -l -0777 -ne 'print for m{(?s)(\{(?:[^{}"]++|"(?:\\.|[^"])*+"|(?1))*\})}g'
db.stats()
EOF

if [[ $ENGINE == 'wiredTiger' ]]
then
echo -e "\n--> Cache size set in wiredTiger engine for mongodb"

CACHE=`cat << EOF | mongo pulp_database | awk -F':' '/\"maximum bytes configured\"/{print $NF}' | tr -d ' ",'
db.serverStatus().wiredTiger.cache
EOF
`

echo -e "  *** `echo $CACHE | awk '{print $1/1024/1024/1024 " GB"}'` "

fi


echo -e "\n--> Gathering the size of all collections for pulp_database inside mongodb. \n"

echo -e "\tName_Of_Collection\t\t\tSize"; echo -e "\t------------------\t\t\t----";

cat << EOF | mongo pulp_database | grep ^pulp | column -s: -t
function getReadableFileSizeString(fileSizeInBytes) {

    var i = -1;
    var byteUnits = [' kB', ' MB', ' GB', ' TB', 'PB', 'EB', 'ZB', 'YB'];
    do {
        fileSizeInBytes = fileSizeInBytes / 1024;
        i++;
    } while (fileSizeInBytes > 1024);

    return Math.max(fileSizeInBytes, 0.1).toFixed(1) + byteUnits[i];
};
var collectionNames = db.getCollectionNames(), stats = [];
collectionNames.forEach(function (n) { stats.push(db[n].stats()); });
stats = stats.sort(function(a, b) { return b['size'] - a['size']; });
for (var c in stats) { print(stats[c]['ns'] + ": " + getReadableFileSizeString(stats[c]['size']) +
" (" + getReadableFileSizeString(stats[c]['storageSize']) + ")"); }
EOF

echo -e "\n\n--> Collecting disk space consumtion by mongodb. \n"

check_mongo_fs_size

echo -e "  *** Present total consumed space in /var/lib/mongodb/ => $SIZE"
echo -e "  *** Present free space in the underlying filesystem   => $FREE_SPACE"


echo

else
   echo -e "  *** The rh-mongodb34-mongod service is not running\n"
   exit 1;
fi

