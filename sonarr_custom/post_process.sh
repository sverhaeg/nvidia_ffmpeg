#!/bin/bash
# Script is basic and does not contain logic for eventypes little testing done so far based on radarr post script
### !!! script assumes symlink ln -s nvidia_ffmpeg.sh in mydir as this is used as working directory of nvidia_ffmpeg.sh
### !!! script needs to owned by sonarr user or is nor run
# In Sonarr, Settings -> Connect add a Custom Script
# On Grab: No
# On Download: Yes
# On Upgrade: Yes
# On Rename: No
# Details on variables
# using dirname sonarr_episodefile_path sonarr_episodefile_path
# https://wiki.servarr.com/sonarr/custom-scripts
#######################  DO   Changes here    #######################
mydir="/media/APPS/torrents/sonarr_custom"
mylogfile="${mydir}/my.log"
grp="adults"
# section 3 is series section to refresh; using external ip iso 172
plexrefresh="https://192.168.5.150:32400/library/sections/3/refresh"
#####################################################################
    now=$(date)
    echo "===================${now}==================" >> ${mylogfile}
    set | grep -e sonarr >> ${mylogfile}
    if [[ -z ${sonarr_eventtype} ]]
    then
        echo "No sonarr event type ... can't do anything" >> ${mylogfile}
        exit
    fi
    if [[ sonarr_eventtype == "Test" ]]
    then
        echo "Test event ... can't do anything" >> ${mylogfile}
        exit
    fi
    echo "event type is ${sonarr_eventtype} " >> ${mylogfile}
    sonarr_serie_path=$(dirname "${sonarr_episodefile_path}")
    echo "sonarr_serie_path is ${sonarr_serie_path}" >> ${mylogfile}
    until [[ -f ${sonarr_episodefile_path} ]]
	do
        echo "====waiting on ${sonarr_episodefile_path} ===" >> ${mylogfile}
        sleep 60
    done
    filesizea=2
    filesizeb=1
    until [[ ${filesizea} = ${filesizeb} ]]
    do
        echo "checking size ${filesizea} vs ${filesizeb}" >> ${mylogfile}
        filesizeb=${filesizea}
        sleep 60
        filesizea=$(stat -c%s "${sonarr_episodefile_path}")
    done
    echo "file not growing anymore ${filesizea} vs ${filesizeb}" >> ${mylogfile}
    echo "===================${now}===================" >> ${mylogfile}
    echo "${sonarr_movie_path}" >> ${mylogfile}
    echo "going to use ${mydir}" >> ${mylogfile}
    cd "${mydir}"
    pwd >> ${mylogfile}
    chmd=`chmod -R ug+rw "${sonarr_serie_path}" 2>&1`
    chgp=`chgrp -R ${grp} "${sonarr_serie_path}" 2>&1`
    echo ${chmd} >> ${mylogfile}
    echo ${chgp} >> ${mylogfile}
    #invoke nvidia convert use Serie option for sonarr otherwise only first episode will be converted if there's a skip condition
    log=`./nvidia_ffmpeg.sh -S -e 5 -d "${sonarr_serie_path}" 2>&1`
    echo ${log} >> ${mylogfile}
    echo ${chmd} >> ${mylogfile}
    echo ${chgp} >> ${mylogfile}
    # -k to ignore certificate
    curl -k ${plexrefresh}
    exit
