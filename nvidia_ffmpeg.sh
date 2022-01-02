#!/bin/bash
#@(#)---------------------------------------------
#@(#) version 0.17
#@(#)   History
#@(#)   v0.07	07jan2021 : first version with revision info
#@(#)   v0.08	08jan2021 : skip for individual file added, leaving overall skip but if deleted still skip actual file
#@(#)   v0.09	09jan2021 : corrected video finder
#@(#)   v0.09	09jan2021 : max_muxing_queue_size 9999
#@(#)   v0.09	11jan2021 : fileoutfull for rm suggestion
#@(#)   v0.10	24jan2021 : enabled getopt with new feature to limit to one file and Force encoding
#@(#)   v0.11   24jan2021 : additional encoders
#@(#)   v0.12   06feb2021 : IFS correction for files
#@(#)   v0.13   06mar2021 : .skip logic with fileoutfull instead of fileout + correct options -? broke all
#@(#)   v0.14   12dec2021 : .skip logic with fileoutfull with .skipffmpegconvert at end iso of begin of file
#@(#)   v0.15   12dec2021 : .skip correction when error
#@(#)   v0.16   31dec2021 : added mpeg2video format and Serie option [.skipffmpegconvert skip for file is still done]
#@(#)   v0.17   01jan2022 : print audiolines of original and correcting series output reincluding .ffmpegconvert_done output 
##################################
#if using snap ffmpeg you need to make sure files are in media or home
# also by default removable-media is not connected to snap
#  to set
#    sudo snap connect ffmpeg:removable-media
#  to check
#    sudo snap connections
#


showHelp() {
# `cat << EOF` This means that cat should stop reading when EOF is detected
cat << EOF
Usage: ./nvidia_ffmpeg.sh -d <directory> -e <encoder>
Encode all known video files using nvidia cuvid hardware for decoding and encoding

-h,    -help,          --help                  Display help

-f,   -file,          --file                  Limit search to file partern (and use dirname for dir)

-d,    -dir,           --dir                   Directory to scan and encode

-e,    -encoder,       --encoder               Enocoder 4|h264 or 5|h265|hvec

-F,    -Force,         --Force                 Force encoding ignore .skip and encoded_by checks

-S,    -Serie,         --Serie                 Do not mark directory .skipffmpegconvert however will not ignore these

-V,    -Verbose,       --Verbose               Verbose with set -xv

-a,    -audiomap,      --audiomap              Overwrite default audio mapping ["-map 0:a"] -- all audio

-s,    -submap,        --submap                Overwrite default subtitle mapping ["-map 0:s:m:language:dut? -map 0:s:m:language:eng? -map 0:s:m:language:fra?"] -- subtitles 3 languanges

-o,    -optionaudio,   --optionaudio           Overwrite audio and sub otpions ["-c:s copy -c:a ac3 -b:a 640k"] -- copy subs and audio in ac3 640k bitrate
EOF
# EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
}


# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "help,file:,dir:,Verbose,Force,Serie,encoder:,audiomap:,submap:,optionaudio:" -o "hf:d:VFSe:a:s:o:" -a -- "$@")

#set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"
#
while true
do
case $1 in
    -h|--help)
        showHelp
        exit 0
        ;;
    -f|--file)
        shift
        export optfile=`basename $1`
        if [[ -z ${optdir} ]]
        then
            export optdir=`dirname $1`
        fi
        ;;
    -d|--dir)
        shift
        export optdir=$1
        ;;
    -F|--Force)
        export Force=1
        ;;
    -S|--Serie)
        export Forceserie=1
        ;;
    -V|--verbose)
        export Verbose=1
        set -xv  # Set xtrace and verbose mode.
        ;;
    -e|--encoder)
        shift
        export optenc=$1
        ;;
    -a|--audiomap)
        shift
        export optaud=$1
        ;;
    -s|--submap)
        shift
        export optsub=$1
        ;;
    -o|--optionaudio)
        shift
        export optopta=$1
        ;;
    --)
        shift
        break;;
    *)
        shift
        break;;
esac
shift
done

###### accept dir and encoder without options
### can work with other options
if [[ -z ${optdir} ]]
then
    export optdir=$1
    shift
fi

if [[ -z ${optenc} ]]
then
    export optenc=$1
fi
#####
###
if [[ -z ${optsub} ]]
then
    map_options_sub="-map 0:s:m:language:dut? -map 0:s:m:language:eng? -map 0:s:m:language:fra?" # subs dut or eng or fra
else
    map_options_sub=${optsub}
fi
if [[ -z ${optaud} ]]
then
    map_options_audio="-map 0:a" #all audio
else
    map_options_audio=${optaud}
fi
 
if [[ -z ${optopta} ]]
then
    audio_subs_options="-c:s copy -c:a ac3 -b:a 640k" ## copy subs and covert audio to ac3 with 640k which is higest supported the default is 480k
else
    audio_subs_options=${optopta}
fi

##echo "start"
##echo "dir provided ${optdir}"
inputdir="${optdir}"
##echo "mode ${optenc}"
# k is used because of old code with simple read
case ${optenc} in
    4|h264)
        k=4
        ##echo "encode in 264"
        ;;
    5|h265|hvec)
        k=5
        ##echo "encode in 265"
        ;;
    *)
        echo "No encoder set use 4|h264 or 5|h265|hvec"
        exit 19
esac
            
#

#using pid to create a work symlink
mypid=$$
if [[ -d ${inputdir} ]]
then
    ln -s "${inputdir}" "work_${mypid}"
    echo "Input dir is ${inputdir}"
    ls -lah "${inputdir}"
    if [[ -f "work_${mypid}/.runningffmpegconvert" ]]
    then
            echo "skip because .runningffmpegconvert"
    rm work_${mypid}
            exit 45
    fi
    if [[ -f "work_${mypid}/.skipffmpegconvert" ]] && [[ -z ${Force} ]]
    then
            echo "skip because .skipffmpegconvert"
            rm "work_${mypid}/.runningffmpegconvert"
    rm work_${mypid}
            exit 53
    fi

    echo "Running ${mypid}" >> work_${mypid}/.runningffmpegconvert
    if [[ -z ${optfile} ]]
    then
        allfiles=`find "work_${mypid}/" -maxdepth 1 -mindepth 1 -type f -size +250M -and  -not \( -name ".*" -or -name "*.AC3.nvidia264.mkv" -or -name "*.AC3.nvidia265.mkv"  \) -and  \( -name "*.mp4" -or -name "*.mkv" -or -name "*.m2ts" -or -name "*.m4v" -or -name "*.avi" \) -print `
    else
        allfiles=`find "work_${mypid}/" -maxdepth 1 -mindepth 1 -name "${optfile}" -print `
    fi
    IFS=$'\n'
    for afile in ${allfiles}
    do
        echo "file $afile"
        decoder=""
        input="${afile}"
        if [[ -f ${input} ]]
        then
            #fileout=`echo ${input} | sed 's/^work_.*\/\(.*\)/\1/'`
            fileoutfull=`echo ${input} | sed 's/^work_.*\///'`
            fileout=`echo ${fileoutfull} | sed 's/\(.m2ts\|.mkv\|.mp4\|.m4v\|.avi\)$//'`
            if [[ $fileout == "" ]]
            then
                echo " something went wrong, check work link "
                rm "work_${mypid}/.runningffmpegconvert"
                exit
            fi
            if [[ -f work_${mypid}/${fileoutfull}.skipffmpegconvert ]] && [[ -z ${Force} ]]
                        then
                                echo "skip of file requested by work_${mypid}/${fileoutfull}.skipffmpegconvert "
                                #next file
                                continue
                        fi
            mkv_lines=`ffmpeg -nostdin -analyzeduration 100M -probesize 100M -i "${input}" 2>&1 | grep -v X11`
            video_lines=`echo "${mkv_lines}" | grep -e Stream | grep -e Video`
            audio_lines=`echo "${mkv_lines}" | grep -e Stream | grep -e Audio`
            #since we are looping make sure whoencoded is cleared
            whoencoded="NOOne"
            #only get first encoded_by occurence this is mkv variable which is not standard so trusting this only used by this script and leaving option to use versions later
            # info : didn't find way to insert this in an existing mkv but if needed you can use the title field of the video to insert this
            # so as work arround use :  mkvpropedit "${input}" --edit info --set "title=" --edit track:v1  --set "name=Video encoded_by ffmpeg_nvidia_hardware"
            # this script inserts the encoded_by as global variable while encoding
            whoencoded=`echo "${mkv_lines}" | grep -i encoded_by | awk 'NR==0; END{print}' | sed "s/.* \(.*\)/\1/"`
            echo "testing whoencoded ${whoencoded}"
            if [[ ${whoencoded} == "ffmpeg_nvidia_hardware" ]]
            then
                echo "HOLD IT this file was already encoded not doing this again found ${whoencoded} in ${afile} or use -Force"
                now=$(date)
                echo "on ${now} already_done [ Force = ${Force} ]  ${fileout} : ${tagenc}'" >> "work_${mypid}/.ffmpegconvert_done"
                if [[ -z ${Force} ]]
                then
                    #next file force not set
                    continue
                fi
            fi
            echo "testing whoencoded is not ffmpeg_nvidia_hardware ${whoencoded}"
            #echo "${video_lines}" >> "details/\"${fileout}\".video"
            #echo "${video_lines}"
            #IFS=$'\n'
            # used for debug lines
            occ=0
            decoder="uNKowN"
            echo "auto select best audio"
            for line in ${audio_lines}
            do
                ((++audiostream))
                echo "${audiostream} : ${line}"
                ##
            done
            ###stop to debug audio###
            exit
            #######
            echo "will look for video encoder"
            for line in ${video_lines}
            do
                ((++occ))
                #echo "${ooc} ${video_lines}" >> "details/\"${fileout}\".video"
                echo "checking stream ${occ}"
                part1=`echo "${line}" | cut -f1 -d','`
                vtype=`echo "${part1}" | sed "s/.*Video:[[:space:]]\([a-zA-Z0-9]*\)[[:space:]].*/\1/"`
                vstream=`echo "${part1}" | sed "s/.*Stream[[:space:]]\#\([0-9]*\):\([0-9]*\).*/\1:\2/"`
                height=`echo "${line}" | sed "s/^.* \([0-9]*\)x\([0-9]*\).*$/\1/" `
                width=`echo "${line}" | sed "s/^.* \([0-9]*\)x\([0-9]*\).*$/\2/" `
                #echo "${occ} ${vstream} ${vtype} ${height} x ${width} "  >> "details/\"${fileout}\".video"
                case ${vtype} in
                    h264)
                    decoder="h264_cuvid"
                        #found decoder stop reading video_lines
                        break
                        ;;
                    hevc)
                        decoder="hevc_cuvid"
                        #found decoder stop reading video_lines
                        break
                        ;;
                    mpeg4)
                        decoder="mpeg4_cuvid"
                        #found decoder stop reading video_lines
                        break
                        ;;
                    mpeg2video)
                        decoder="mpeg2_cuvid"
                        #found decoder stop reading video_lines
                        break
                        ;;
                    mpeg2)
                        decoder="mpeg2_cuvid"
                        #found decoder stop reading video_lines
                        break
                        ;;
                    vc1)
                        decoder="vc1_cuvid"
                        #found decoder stop reading video_lines
                        break
                        ;;
                    vp8)
                        decoder="vp8_cuvid"
                        #found decoder stop reading video_lines
                        break
                        ;;
                    vp9)
                        decoder="vp9_cuvid"
                        #found decoder stop reading video_lines
                        break
                        ;;
                    *)
                        decoder="uNKowN"
                esac
            done
            #    unset IFS
            echo "VIDEO is ${vstream} ${vtype} ${height} ${width} $decoder"
            #echo "VIDEO is ${vstream} ${vtype} ${height} ${width} $decoder" >> "details/\"${fileout}\".video"
            #eval ${cmdcheckaudio}
            #eval ${cmdcheckvideo}
            map_options="-map ${vstream} ${map_options_audio} ${map_options_sub}"
            echo " map : ${map_options}"
            # k is used because of old code with simple read
            case $k in
                    4)
                        encoder="-c:V h264_nvenc -preset:V hq -profile:V high -rc-lookahead 20"
                        tagenc="nvidia264"
                        ;;
                    5)
                        encoder="-c:V hevc_nvenc -preset:V hq -profile:V main10 -rc-lookahead 20"
                        tagenc="nvidia265"
                        ;;
                     *)
                        printf "Do not have a target encoder is not possible here ABORT"
                        exit 161
            esac
            encoded_by="ffmpeg_nvidia_hardware"
            mkvtitle="" # Removing tag title is often bogus
                        echo "using encoder ${encoder}"
                        echo "using append  ${tagenc}"
            echo "using encoded_by ${encoded_by}"
            echo "using empty title for now ${mkvtitle}"
            # important use -nostdin otherwise ffmpeg will freeze when there're multiple files to encode in the same run
            # decided after testing to use only features directly supported by nvidia and leave as much as possible defaults using preset hq which is best quality with max 3 b frames (bd is same with 2)
            command_recode=`echo "ffmpeg -nostdin -v error -stats -analyzeduration 100M -probesize 100M -hwaccel cuvid -c:v ${decoder} -hwaccel_output_format cuda -i \"${input}\" -metadata title=${mkvtitle} -metadata encoded_by=${encoded_by} ${map_options} ${encoder} ${audio_subs_options} -map_metadata 0 -movflags use_metadata_tags -max_muxing_queue_size 9999 \"work_${mypid}/${fileout}.AC3.${tagenc}.mkv\""`
            echo "command to recode : ${command_recode}"
            # nvidia-smi encodersessions not working
            limit=`nvidia-smi | grep " C " | wc -l`
            echo ${limit}
            while (( limit > 2 ))
            do
                echo " to many jobs running ${limit} check nvidia-smi waiting 10 min"
                sleep 600
            done
            echo " ok to start a new only running ${limit} jobs nvidia-smi type C"
            eval ${command_recode}
            cresult=$?
            if [[ ${cresult} == 0 ]]
            then
                echo "ffmpeg success : work_${mypid}/${fileout}.AC3.${tagenc}.mkv"
                filesizenew=$(stat -c%s "work_${mypid}/${fileout}.AC3.${tagenc}.mkv")
                filesizeold=$(stat -c%s "${input}")
                echo "Size of new ${filesizenew} vs old ${filesizeold}"
                if (( filesizenew > filesizeold )); then
                        echo "nope new file bigger [[ Force = ${Force} ]] ${input} "
                    if [[ -z ${Force} ]]
                    then
                        if [[ -z ${Forceserie} ]]
                        then
                            echo "Reason conversion larger '${inputdir}' file ${fileout} " >> "work_${mypid}/.skipffmpegconvert"
                        fi
                        echo "Reason conversion larger '${inputdir}' file ${fileout} " >> "work_${mypid}/${fileoutfull}.skipffmpegconvert"
                        rm "work_${mypid}/${fileout}.AC3.${tagenc}.mkv"
                        #Try next movie file, this will try all files ones in this (series) directory and skip next time
                        continue
                    else
                        echo "FORCE so keeping larger file"
                    fi
                else
                        echo "size is fine"
                fi
                echo "post processing finding str"
                #find "work_${mypid}/" -maxdepth 2 -mindepth 1 -type f -and \( -name "*.srt" -or -name "*.nfo" -or -name "*.jpg" -or -name "*.smi" -or -name "*.idx" -or -name "*.sub" \) -and -not \( -name "*.nvidia264.*" -or -name "*.nvidia265.*" \) -print0 | while read -d $'\0' srtfile
                find "work_${mypid}/" -maxdepth 2 -mindepth 1 -type f -name "${fileout}*" -and \( -name "*.srt" -or -name "*.nfo" -or -name "*.jpg" -or -name "*.smi" -or -name "*.idx" -or -name "*.sub" \) -and -not \( -name "*.AC3.nvidia264.*" -or -name "*.AC3.nvidia265.*" \) -print0 | while read -d $'\0' srtfile
                do
                    echo "original ${srtfile} need ${fileout} with AC3 and ${tagenc}"
                    newstr=`echo "${srtfile}" | sed "s/${fileout}/${fileout}.AC3.${tagenc}/"`
                    echo "new srt ${newstr}"
                    cpsrtcmd="cp -p \"${srtfile}\" \"${newstr}\""
                    eval ${cpsrtcmd}
                    echo "ready to copy : ${cpsrtcmd}"
                    eval ${cpsrtcmd}
                done
                mvcmd=`echo "mv \"${input}\" \"${input}_converted_${tagenc}\""`
                echo "rm '${inputdir}/${fileoutfull}_converted_${tagenc}'" >> conversion_completed
                now=$(date)
                echo "on ${now} completed ${fileout} : ${tagenc}'" >> "work_${mypid}/.ffmpegconvert_done"
                echo " Audio was ${audio_lines}" >> "work_${mypid}/.ffmpegconvert_done"
                echo "will do : ${mvcmd}"
                eval ${mvcmd}
            else
                echo "Error ffmpeg result ${cresult}"
                if [[ -z ${Forceserie} ]]
                then
                    echo "Reason ffmpeg error '${inputdir}' file ${fileout} : ${cresult}" >> "work_${mypid}/.skipffmpegconvert"
                fi
                echo "Reason ffmpeg error '${inputdir}' file ${fileout} : ${cresult}" >> "work_${mypid}/${fileoutfull}.skipffmpegconvert"
                echo "Reason ffmpeg error '${inputdir}' ${cresult}" >> conversion_failed
                rm "work_${mypid}/${fileout}.AC3.${tagenc}.mkv"
                #Try next movie file, this will try all files ones in this (series) directory and skip next time
                                continue
            fi
        else
            echo "Error: file ${input} not found"
        fi
    done
    unset IFS
else
    echo "Provide exiting dir or include in filename"
fi
# cleanup
rm "work_${mypid}/.runningffmpegconvert"
now=$(date)
echo "Script ran with ${options} on $(date)"  >> "work_${mypid}/.ffmpegconvert_done"
echo "Script ran with ${options} on $(date)"
echo " Audio was ${audio_lines}"
rm work_${mypid}
