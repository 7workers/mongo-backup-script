#!/bin/bash
# usage example: mongo-backup.sh --maxSnapshots 5 --mongoPort 27018 --backupHome /path/to/dir
# put file names skip_backup.txt into backup home dir with database names one per line

backupHome=""
mongoPort=27018
maxSnapshots=5

while [ $# -gt 0 ]; do
   if [[ $1 == *"--"* ]]; then
        param="${1/--/}"
        declare $param="$2"
   fi
  shift
done

if [[ "$backupHome" = "" ]]; then
	echo "SPECIFY BACKUP HOME DIR: --backupHome /path/to/dir/ "
	exit
fi

load=`cut -f 1 -d " " /proc/loadavg`
hostName=`hostname`
fnameLoad="${backupHome}/load_nodes.txt"
fnameSkipDbs="${backupHome}/skip_backup.txt"
isMaster=`mongo --port $mongoPort --eval "rs.isMaster()" | grep master | grep -o false`

skipDbsLine=""

if [[ -f "$fnameSkipDbs" ]]; then
	while read -r line; do
		skipDbsLine+="*${line}*"
	done < "$fnameSkipDbs"
fi

echo "`date +"%m-%d-%Y %T"` THIS HOSTNAME: $hostName LOAD: $load BACKUP HOME: $backupHome"

if [ "$isMaster" != "false" ]
then
	echo  > $fnameLoad
	echo "`date +"%m-%d-%Y %T"` THIS IS NOT A SECONDARY NODE. WILL PERFORM MAINTENANCE AND EXIT"
	nofSnapshots=`ls -l1 $backupHome | grep ^d | wc -l`
	if [[ "$nofSnapshots" -gt "$maxSnapshots" ]]; then
		oldestBackup="${backupHome}`ls -l1t $backupHome | grep ^d | tail -n 1 | grep -Po "[^\s]+$"`"
		echo "`date +"%m-%d-%Y %T"` DELETING OLDEST SNAPSHOT: $oldestBackup ..."
		rm -rf $oldestBackup
		echo "`date +"%m-%d-%Y %T"` DONE."
	fi
	exit
fi

echo "`date +"%m-%d-%Y %T"` WITING FOR EXACT TIME..."

if [ `date +"%S"` = "00" ]
then
	sleep 58
fi

while [[ `date +"%S"` != "00"  ]]; do
	sleep 1
done

echo "$load $hostName" >> $fnameLoad
sleep 2
bestNode=`sort $fnameLoad | head -n 2 | tail -n 1 | cut -d' ' -f2`

if [ "$bestNode" = "$hostName" ]
then
	echo "`date +"%m-%d-%Y %T"` BEST LOAD ON: $bestNode (THIS NODE). GETTING READY FOR BACKUP PROCEDURE..."
else
	echo "`date +"%m-%d-%Y %T"` BEST LOAD ON: $bestNode (NO THIS NODE). EXITING."
	exit	
fi

dirNameBackup="${backupHome}`date +"%m-%d-%Y_%T"`"

while read -r line; do
	case $line in
		admin | config | local )
			;;
		*)
			if [[ "$skipDbsLine"  == *"*${line}*"* ]];
			then
				echo "`date +"%m-%d-%Y %T"` SKIPPING: $line"
			else
				echo "`date +"%m-%d-%Y %T"` --- $line -----------------------------------------------------------------------------------------------------------"	

				mongodump --port $mongoPort --gzip -d $line -o $dirNameBackup
			fi
			;;
	esac
done < <(mongo --port ${mongoPort} --eval "rs.slaveOk();db.adminCommand({listDatabases:1})" | grep -oP '([^"]+)",' | grep -Po '[^",]+')
