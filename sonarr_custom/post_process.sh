#!/bin/bash

# Examples for testing
#
# In Sonarr, Settings -> Connect add a Custom Script
# On Grab: No
# On Download: Yes
# On Upgrade: Yes
# On Rename: No
# Details on variables
# https://wiki.servarr.com/sonarr/custom-scripts
mydir="/media/APPS/torrents/sonarr_custom"
##### script assumes symlink off nvidia_ffmpeg.sh in mydir as this is used as working directory of nvidia_ffmpeg.sh
mylogfile="${mydir}/my.log"
usrgrp="boss:adults"
# section 3 is movie shows refresh
plexrefresh="https://192.168.5.150:32400/library/sections/3/refresh"
	now=$(date)
	echo "===================${now}==================" >> ${mylogfile}
	set | grep -e sonarr >> ${mylogfile}
     if [[ -z ${sodarr_eventtype} ]]
    then
        echo "No sonarr event type ... can't do anything" >> ${mylogfile}
        exit
    fi
	if [[ sonarr_eventtype == "Test" ]]
	then
		echo "Test event ... can't do anything" 
		exit
	fi
    echo "event type is ${sonarr_eventtype} "
	until [[ -f ${sonarr_episodefile_sourcepath} ]]
	do
	echo "====waiting on ${sonarr_episodefile_sourcepath} ===" >> ${mylogfile}
	sleep 60
	done
	filesizea=2
        filesizeb=1
	until [[ ${filesizea} = ${filesizeb} ]]
	do
		echo "checking size ${filesizea} vs ${filesizeb}" >> ${mylogfile}
		filesizeb=${filesizea}
		sleep 60
		filesizea=$(stat -c%s "${sonarr_episodefile_sourcepath}")
	done

	echo "file not growing anymore ${filesizea} vs ${filesizeb}" >> ${mylogfile}

	echo "===================${now}===================" >> ${mylogfile}
	echo ${sonarr_movie_path} >> ${mylogfile}
	cd /media/APPS/torrents/sonarr_custom
	#use Serie option for sonarr otherwise only first episode will be converted
	log=`./nvidia_ffmpeg.sh -S -d "${sonarr_episodefile_path}" -e 5 2>&1`
	chmod -R ug+rw ${sonarr_episodefile_path}
	chown -R boss:adults ${sonarr_episodefile_path}
	echo ${log} >> ${mylogfile}
	
	# -k to ignore certificate
	curl -k "https://192.168.5.150:32400/library/sections/3/refresh"
	exit

