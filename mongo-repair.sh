#!/bin/bash

echo -e "\n** NOTE: Please ensure that there are no tasks running in satellite server or no activities going on as satellite services will be down when this maintenance activity is going on. ***\n"

check_mongo_fs_size ()
{

unset SIZE FREE_SPACE
SIZE=`du -sh /var/lib/mongodb/ | awk '{print $1}'`
FREE_SPACE=`df -hPT /var/lib/mongodb/ | awk 'NR>1{print $4}'`

}

check_mongo_fs_size

echo -e "\n** NOTE: Ensure that you have free space in /var/lib/mongodb/ which should be more than or equal to the size of your current data set plus 2 gigabytes. **"
echo "**** Present total consumed space in /var/lib/mongodb/ => $SIZE"
echo "**** Present free space in the underlying filesystem   => $FREE_SPACE"

echo " "

read -p "Do you want to proceed further ? [ Hit y to start or n to quit ] : " confirm ;

if [ $confirm == 'n' ] || [ $confirm == 'no' ] || [ $confirm == 'N' ] || [ $confirm == 'NO' ] || [ $confirm == 'No' ]
then
  echo -e "\n Cancelling the script execution now.. \n"
  exit 1
elif [ $confirm == 'y' ] || [ $confirm == 'yes' ] || [ $confirm == 'Y' ] || [ $confirm == 'YES' ] || [ $confirm == 'Yes' ]
then

  echo -e "\n--> Stopping all Satellite or Capsule services now....... \n"
  foreman-maintain service stop

  echo -e "\n--> Running repair on mongo database.......... \n"
  mongod --dbpath  /var/lib/mongodb/  --repair
  sleep 4

  echo -e "\n--> Ensuring correct file permissions are set. \n"
  chown -R mongodb:mongodb /var/lib/mongodb/* 
     
  echo -e "\n--> Restarting all satellite or capsule services.......  \n"
  foreman-maintain service restart
  sleep 6

  echo -e "\n--> Checking satellite or capsule health...............  \n"
  foreman-maintain service status -b
  echo -e "\n\n"
  sleep 2
  rpm -q satellite &>/dev/null && hammer ping
  echo " "

  check_mongo_fs_size
  echo "**** Now, total consumed space in /var/lib/mongodb/ => $SIZE"
  echo "**** Now, free space in the underlying filesystem   => $FREE_SPACE"


else
  echo -e "\n Please provide a valid input i.e. either yes or no. \n"
  exit 1
fi

