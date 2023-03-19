#!/bin/bash
# Script is looking at the queue directories for new added jobs
### !!! script assumes symlink ln -s nvidia_ffmpeg.sh in mydir as this is used as working directory of nvidia_ffmpeg.sh
#######################  DO Changes in config    #######################
BASEDIR=$(dirname "$0")
source ${BASEDIR}/.config
### file .config needs
# token=xyYYYYYYYYzzzzzz6666
# section=3
# grp="adults"
# mydir="/media/APPS/torrents/sonarr_custom"
# mylogfile="${mydir}/my.log"
# serverport=127.0.0.1:32400
# get the server token by opening https://plex.tv/pms/servers.xml?X-Plex-Token=<with a temp token from xml view of file >
plexrefresh="https://${serverport}/library/sections/${section}/refresh?X-Plex-Token=${token}"
plexsection="https://${serverport}/library/sections/${section}?X-Plex-Token=${token}"
#####################################################################
    #need to use real iso mapped
    mydir=${myrealdir}
    mylogfile=${myreallogfile}
    # now=$(date +"%x_%X")
    # Only show time
    now=$(date +"%H%I ")
    echo -n "${now}=" >> ${mylogfile}
    #echo "==== plex section check=" >> ${mylogfile}
    #curl -k ${plexsection} | grep -e key\=\"all\" >> ${mylogfile}
    cd "${mydir}"
    #pwd >> ${mylogfile}
    if [[ -f "queue/.running" ]]
    then
	    exit
    fi
    echo $$ > queue/.running
    IFS=$'\n'
    for job in `find ./queue -name "*.added" -type f`
    do
      echo "===" >> ${mylogfile}
      now=$(date)
      echo "=${now}=" >> ${mylogfile}
	    echo "${job} found " >> ${mylogfile}
	    newjobfile=$(sed 's/added$/converting/' <<< ${job})
	    endjobfile=$(sed 's/added$/done/' <<< ${job})
	    echo will start ${newjobfile} when done ${endjobfile} >> ${mylogfile}
	    mv ${job} ${newjobfile} >> ${mylogfile}
            log=`. ${newjobfile} 2>&1`
	    echo ${log} >> ${mylogfile}
	    mv ${newjobfile} ${endjobfile}
	    # -k to ignore certificate curl -k
      curl -k ${plexrefresh} 1>/dev/null 2>&1
    done
    rm "queue/.running"
    exit