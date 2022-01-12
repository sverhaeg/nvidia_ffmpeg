#!/bin/bash
# Script is basic and does not contain logic for eventypes
### !!! script assumes symlink ln -s nvidia_ffmpeg.sh in mydir as this is used as working directory of nvidia_ffmpeg.sh
### !!! script needs to owned by radarr user or is nor run
# In Radarr, Settings -> Connect add a Custom Script
# On Grab: No
# On Download: Yes
# On Upgrade: Yes
# On Rename: No
# Details on variables
# https://wiki.servarr.com/Radarr_Tips_and_Tricks#Custom_Post_Processing_Scripts
#######################  DO   Changes here    #######################
mydir="/media/APPS/torrents/radarr_custom"
mylogfile="${mydir}/my.log"
grp="adults"
# section 2 is movie refresh to refresh; using external ip iso 172
plexrefresh="https://192.168.5.150:32400/library/sections/2/refresh"
#####################################################################
    now=$(date)
    echo "===================${now}===================" >> ${mylogfile}
    set | grep -e radarr >> ${mylogfile}
    if [[ -z ${radarr_eventtype} ]]
    then
        echo "No radarr event type ... can't do anything" >> ${mylogfile}
        exit
    fi
    if [[ ${radarr_eventtype} == "Test" ]]
    then
        echo "Test event ... can't do anything" >> ${mylogfile}
        exit
    fi
    echo "event type is ${radarr_eventtype} " >> ${mylogfile}
    echo "radarr_moviefile_path is ${radarr_moviefile_path}" >> ${mylogfile}
    # first time only sleep 5 firt time unless the file was not there otherwise 60
    filesleep="5"
    until [[ -f ${radarr_moviefile_path} ]]
    do
        echo "====waiting on ${radarr_moviefile_path} ===" >> ${mylogfile}
        sleep 60
        #no need to rush file is being copied
        filesleep="60"
    done
    filesizea=$(stat -c%s "${radarr_moviefile_path}")
    filesizeb=1
    until [[ ${filesizea} = ${filesizeb} ]]
    do
        echo "checking size ${filesizea} vs ${filesizeb}" >> ${mylogfile}
        filesizeb=${filesizea}
        sleep ${filesleep}
        filesizea=$(stat -c%s "${radarr_moviefile_path}")
        # switch to 60 sleep as for now
        filesleep="60"
    done
    echo "file not growing anymore ${filesizea} vs ${filesizeb}" >> ${mylogfile}
    echo "===================${now}===================" >> ${mylogfile}
    set | grep -e radarr >> ${mylogfile}
    echo "${radarr_movie_path}" >> ${mylogfile}
    echo "going to use ${mydir}" >> ${mylogfile}
    cd "${mydir}"
    pwd >> ${mylogfile}
    #sleep 1000
    chmd=`chmod -Rf ug+rw "${radarr_movie_path}" 2>&1`
    chgp=`chgrp -Rf ${grp} "${radarr_movie_path}" 2>&1`
    echo ${chmd} >> ${mylogfile}
    echo ${chgp} >> ${mylogfile}
    #invoke nvidia convert
    #log=`./nvidia_ffmpeg.sh -e 5 -d "${radarr_movie_path}" 2>&1`
    ## with file iso directory
    echo "Starting nvidia_ffmpeg.sh" >> ${mylogfile}
    log=`./nvidia_ffmpeg.sh -e 5 -f "${radarr_moviefile_path}" -t "${radarr_movie_title}" 2>&1`
    echo ${log} >> ${mylogfile}
    echo ${chmd} >> ${mylogfile}
    echo ${chgp} >> ${mylogfile}
    # -k to ignore certificate curl -k
    curl -k ${plexrefresh}
    exit
