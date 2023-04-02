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
# using dirname sonarr_episodefile_path : sonarr_serie_path
# https://wiki.servarr.com/sonarr/custom-scripts
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

    now=$(date)
    echo "===================${now}===================" >> ${mylogfile}
    set | grep -e sonarr >> ${mylogfile}
    echo "event type is ${sonarr_eventtype} " >> ${mylogfile}
    case ${sonarr_eventtype} in
        Test)
            echo "Test event ... can't do anything" >> ${mylogfile}
            exit
            ;;
        Upgrade|Download)
            echo "Event type known [Upgrade|Download]"
            ;;
        *)
            echo "No known event type ... can't do anything" >> ${mylogfile}
            exit
    esac
    sonarr_serie_path=$(dirname "${sonarr_episodefile_path}")
    echo "sonarr_serie_path is ${sonarr_serie_path} [not used]" >> ${mylogfile}
    # first time only sleep 5 firt time unless the file was not there otherwise 60
    filesleep="5"
    echo "==== plex section check=" >> ${mylogfile}
    curl -k ${plexsection} | grep -e key\=\"all\" >> ${mylogfile}
    until [[ -f ${sonarr_episodefile_path} ]]
	do
        echo "====waiting on ${sonarr_episodefile_path} ===" >> ${mylogfile}
        sleep 60
        #no need to rush file is being copied
        filesleep="60"
    done
    filesizea=$(stat -c%s "${sonarr_episodefile_path}")
    filesizeb=1
    until [[ ${filesizea} = ${filesizeb} ]]
    do
        echo "checking size ${filesizea} vs ${filesizeb}" >> ${mylogfile}
        filesizeb=${filesizea}
        sleep ${filesleep}
        filesizea=$(stat -c%s "${sonarr_episodefile_path}")
        # switch to 60 sleep as for now
        filesleep="60"
    done
    echo "file not growing anymore ${filesizea} vs ${filesizeb}" >> ${mylogfile}
    echo "===================${now}===================" >> ${mylogfile}
    echo "${sonarr_movie_path}" >> ${mylogfile}
    echo "going to use ${mydir}" >> ${mylogfile}
    cd "${mydir}"
    pwd >> ${mylogfile}
    chmd=`chmod -Rf ug+rw "${sonarr_serie_path}" 2>&1`
    chgp=`chgrp -Rf ${grp} "${sonarr_serie_path}" 2>&1`
    echo ${chmd} >> ${mylogfile}
    echo ${chgp} >> ${mylogfile}
    #invoke nvidia convert use Serie option for sonarr otherwise only first episode will be converted if there's a skip condition
    #log=`./nvidia_ffmpeg.sh -S -e 5 -d "${sonarr_serie_path}" 2>&1`
    metatitle="${sonarr_series_title} : ${sonarr_episodefile_episodetitles}"
    echo "### Adding ${sonarr_download_id} to queue" >> ${mylogfile}
    mapped_path=`echo ${sonarr_episodefile_path} | eval ${mappings}`
    echo "./nvidia_ffmpeg.sh -S -e 5 -f \"${mapped_path}\" -t \"${metatitle}\""  >> ${mylogfile}
    jobname="${sonarr_download_id}_${sonarr_series_title}_${sonarr_episodefile_id}_${sonarr_episodefile_episodecount}_${sonarr_episodefile_episodeids}_${sonarr_episodefile_episodenumbers}"
    echo "./nvidia_ffmpeg.sh -S -e 5 -f \"${mapped_path}\" -t \"${metatitle}\" "  > ${mydir}/queue/${jobname}.added
    ls -la "${mydir}/queue/${jobname}.added" >> ${mylogfile}
    cat "${mydir}/queue/${jobname}.added" >> ${mylogfile}
    echo "### Adding to queue done" >> ${mylogfile}
    #log=`./nvidia_ffmpeg.sh -S -e 5 -f "${sonarr_episodefile_path}" -t "${metatitle}" 2>&1`
    #echo ${log} >> ${mylogfile}
    chmd=`chmod -Rf ug+rw "${sonarr_serie_path}" 2>&1`
    chgp=`chgrp -Rf ${grp} "${sonarr_serie_path}" 2>&1`
    echo ${chmd} >> ${mylogfile}
    echo ${chgp} >> ${mylogfile}
    # -k to ignore certificate
    #curl -k ${plexrefresh}
    exit
