#!/bin/bash

echo -e "\n** NOTE: Please ensure that there are no tasks running in satellite server or no activities going on as satellite services will be down when this maintenance activity is going on. ***\n"

read -p "Do you want to proceed further ? [ Hit y to start or n to quit ] : " confirm ;

if [ $confirm == 'n' ] || [ $confirm == 'no' ] || [ $confirm == 'N' ] || [ $confirm == 'NO' ] || [ $confirm == 'No' ]
then
  echo -e "\n Cancelling the script execution now.. \n"
  exit 1
elif [ $confirm == 'y' ] || [ $confirm == 'yes' ] || [ $confirm == 'Y' ] || [ $confirm == 'YES' ] || [ $confirm == 'Yes' ]
then
  rpm -q satellite &>/dev/null && SAT='TRUE' || SAT='FALSE'

  if [[ $SAT == 'TRUE' ]]
  then
  echo -e "\n--> Stopping all Satellite services now....... \n"
  foreman-maintain service stop

  echo -e "\n--> Starting postgresql service now........... \n"
  systemctl start postgresql

  echo -e "\n--> Checking status of postgresql service.....  "
  systemctl is-active postgresql &> /dev/null && STAT='active' || STAT='dead'

  echo -e "***** $STAT"

     if [[ $STAT != 'active' ]]
     then
       echo -e "\nCheck and fix the postgres service.\n"
       exit 1;
     else
       echo -e "\n--> Vaccuming postgres database................ \n"
       runuser -u postgres -- vacuumdb -afz
       if [ $? -eq '0' ]
       then
         sleep 4
         echo -e "\n--> Re-indexing postgres database.............. \n"
         runuser -u postgres -- reindexdb -a
         sleep 4
       else
	 echo -e "\nCheck and fix the error with vacuuming.\n"
	 exit 1;
       fi
     fi

  echo -e "\n--> Restarting all satellite services.......  \n"
  foreman-maintain service restart
  sleep 6

  echo -e "\n--> Checking satellite health...............  \n"
  foreman-maintain service status -b
  echo -e "\n\n"
  hammer ping
  echo " "

  fi  

else
  echo -e "\n Please provide a valid input i.e. either yes or no. \n"
  exit 1
fi

