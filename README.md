The script should be started at the exact same time on all replica set nodes

It will exit if started on PRIMARY

SECONDARIES with least load average will be picked and dump will be performed using mongodbum: https://docs.mongodb.com/manual/reference/program/mongodump/

run on every node by cron, example:

`11 4 * * MON mongo-backup.sh --backupHome /mounted/nfs/backup >> /mounted/nfs/backup/this-hostname.backup.log`

parameters:

**backupHome** - path to shared / mounted storage, example: ` --backupHome /mnt/backups/mongo-backup/ `

**mongoPort** - mongodb port (27018 is default for replica set node), example: ` --mongoPort 27018 `

**maxSnapshots** - max backup directories to keep, example: ` --maxSnapshots 5 `

== Ignoring specific database during backup ==

create file named `skip_backup.txt` in the backup home directory and put database names one per line
