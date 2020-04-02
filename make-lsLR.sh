#!/bin/bash
#
# Usage: ./make-lsLR.sh 
#
# Purpose:
# to make a file that is parseable for recovering
# a filled /lost+found directory by parsing 
# filesize, md5sum, permissions and path+filename
# 
# Author: Ingo Juergensman - http://blog.windfluechter.net
# License: GPL v2, see http://gnu.org for details. 
#
# first: get all directories
#set -x
#disable globbing: 
set -f 
# fail silently when a Xen Kernel is loaded
if [ `uname -r | grep xen-686` ]; then 
	exit 0
fi
HOST=`hostname`

if [[ -s /var/run/make-lsLR.pid ]]; then 
	PID=$$
	LASTPID=`cat /var/run/make-lsLR.pid`
	if [[ ${PID} -ne ${LASTPID} ]]; then 
		if ! kill ${LASTPID} > /dev/null 2>&1; then
			# no old process can be found, deleting PID file
			#echo "Could not send SIGTERM to process $pid" >&2
			rm /var/run/make-lsLR.pid
		else 
			#echo "script already running. exiting..."
			exit 0
		fi
	fi
fi

echo ${PID} > /var/run/make-lsLR.pid

#exit 0

# check whether a full backup is running on this host or not
check_running () {
	check_full=`su - backuppc -c "/usr/share/backuppc/bin/BackupPC_serverMesg status jobs" | grep -e BackupPC_dump -e BackupPC_nightly`
	while [ -n "$check_full" ]; do
		check_full=`su - backuppc -c "/usr/share/backuppc/bin/BackupPC_serverMesg status jobs" | grep -e BackupPC_dump -e BackupPC_nightly`
		#echo "Fullbackup running"
		sleep 300
	done
}

check_running

nice -20 find /srv/video/ij -path /sys -prune -o \
		-path /proc -prune -o \
		-path /var/lib/backuppc -prune -o \
		-path /var/spool/squid -prune -o \
		-path /srv/timemachine -prune -o \
		-path /media -prune -o \
		-path /var/cache/minidlna -prune -o \
		-path /mnt -prune -o \
		-path /var/spool/ftn/filebase -prune -o \
		\( -name .AppleDouble -o -name .AppleDB -o -name .AppleDesktop \) -prune -o \
		-type d -printf  "%U:%G %#m " -exec echo "{}" \; > /root/ls-md5sum-dirs.txt.new



# next: get all relevant information
#for DIR in `cat /root/ls-md5sum-dirs.txt.new | awk '{print $3}'`; do 
OLDIFS=$IFS
IFS=$'\n'
for DIR in `cat /root/ls-md5sum-dirs.txt.new | cut -d" " -f3-`; do
	#echo "$i Directory: ${DIR}" 
	((i++))
	if [ $i -eq 100 ] ; then 
		i=0 
		check_running
	fi
	nice -20 find "${DIR}" -maxdepth 1 -not -name .AppleDouble -not -name .AppleDB -not -name .AppleDesktop \
		-type f -printf "%s %U:%G %#m " \
		-exec nice -15 md5sum '{}' \; | tr -s " " >> /root/ls-md5sum-files.txt.new
done
IFS=$OLDIFS

# keep a backup file
if [ -e /root/ls-md5sum-dirs.txt ]; then 
	#echo "mv dirs.1"
	mv /root/ls-md5sum-dirs.txt /root/ls-md5sum-dirs.txt.1
	if [ -e /root/ls-md5sum-dirs.txt.1.gz ]; then 
		#echo "rm dirs"
		rm /root/ls-md5sum-dirs.txt.1.gz
	fi
	gzip -9 /root/ls-md5sum-dirs.txt.1
fi

if [ -e /root/ls-md5sum-files.txt ]; then 
	#echo "mv files.1"
	mv /root/ls-md5sum-files.txt /root/ls-md5sum-files.txt.1
	if [ -e /root/ls-md5sum-files.txt.1.gz ]; then 
		#echo "rm files"
		rm /root/ls-md5sum-files.txt.1.gz
	fi
	gzip -9 /root/ls-md5sum-files.txt.1
fi

mv /root/ls-md5sum-dirs.txt.new /root/ls-md5sum-dirs.txt
mv /root/ls-md5sum-files.txt.new /root/ls-md5sum-files.txt

