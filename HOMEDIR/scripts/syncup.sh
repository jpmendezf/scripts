#!/bin/bash

##
## Syncup
##

# Syncup is a script to create incremental backups of several Remote systems
# using rsync and hardlinks. 

# Copyright 2011 Eugene E. Kashpureff (eugene@kashpureff.org)
# License: GNU General Public License, version 3+

##
## Environment Setup
##

## Runtime vars
# Working directory. Backups are kept here.
BASEDIR="/data/backups"
# Concurrency lock-prevention dir
LOCKDIR="${BASEDIR}/.lock"
# Timestamp format to use
TIMESTAMP="date +%s"
# File containing remote names
REMOTES="${BASEDIR}/.remotes"
# Directory to read remote:/sources/
SOURCEDIR="${BASEDIR}/.sources"
# Number of incremental backups to keep
INCREMENTALS="14"
# Backup frequency(used as a naming string only)
FREQUENCY="daily"
# Bandwidth limit, in KB/s(0 for unlimited)
BWLIMIT="250"
# Extra options for rsync
RSYNCOPTS=${1}

## Env vars


##
## Script Lock
##

# Attempt to acquire lock
if mkdir "${LOCKDIR}"
then
	echo $$ > "${LOCKDIR}/pid"
else
	echo "Error: Unable to acquire script lock"
	exit
fi

# Remove lock on exit, even if abnormal
trap "rm -rf ${LOCKDIR}; exit" INT TERM EXIT

##
## Remote Syncing
##

# Loop through each defined Remote
while read remote
do
	# Extra space for readability
	echo ""
	echo "Remote: ${remote}"
	# Directory to save backups into
	backdir="${BASEDIR}/${remote}"
	# Base name for backups
	backbase="${backdir}/${FREQUENCY}"
	
	# Check that a list of Sources exists
	if [ ! -f "${SOURCEDIR}/${remote}" ]
	then
		echo "Error:  No Sources list found"
		# Abort this Remote
		continue
	fi
	
	# Check for $backdir, create if needed
	if [ -d "${backdir}" ]
	then
		# Check for #0, fail if it's not there
		if [ ! -d "${backbase}.0" ]
		then
			echo "Error:  Backup #0 is missing."
			# Abort this Remote
			continue
		fi
	else
		# Create backdir if it doesn't exist(eg, first-run)
		mkdir "${backdir}"
		mkdir "${backbase}.0"
	fi
	
	# Rotate backups only if #0 is complete(overwrite otherwise)
	if [ -f ${backbase}.0/.timestamp ]
	then
		# Remove oldest backup
		if [ -d "${backbase}.${INCREMENTALS}" ]
		then
			rm -rf "${backbase}.${INCREMENTALS}"
		fi
		
		# Move all old backups up by one
		i=${INCREMENTALS}
		while [ $i -gt 1 ]
		do
			if [ -d "${backbase}.$[$i-1]" ]
			then	
				mv "${backbase}.$[i-1]" "${backbase}.${i}"
			fi
			i=$[$i-1]
		done
		unset i
		
		# Hard-link a new #1 from #0
		cp -al "${backbase}.0" "${backbase}.1"
		# Remove timestamp from #0
		rm -f "${backbase}.0/.timestamp"
	fi
	
	# Loop through Sources
	while read source
	do
		# Current Source being synced
		echo "Source: ${source}"
		
		# Rsync remote:/source/ into the backup dir
		rsync -rltzR --bwlimit=${BWLIMIT} --delete-during ${RSYNCOPTS} ${source} ${backbase}.0
	done < ${SOURCEDIR}/${remote}
	unset source
	
	${TIMESTAMP} > "${backbase}.0/.timestamp"
	
done < ${REMOTES}
unset remote backdir

##
## Cleanup
##

# Get rid of variables
unset BASEDIR LOCKDIR TIMESTAMP REMOTES SOURCEDIR INCREMENTALS FREQUENCY BWLIMIT 
unset RSYNCOPTS
