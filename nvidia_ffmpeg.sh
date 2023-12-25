#!/bin/bash
#@(#)---------------------------------------------
#@(#) version 0.31
#@(#)   History
#@(#)   v0.07	07jan2021 : first version with revision info
#@(#)   v0.08	08jan2021 : skip for individual file added, leaving overall skip but if deleted still skip actual file
#@(#)   v0.09	09jan2021 : corrected video finder
#@(#)   v0.09	09jan2021 : max_muxing_queue_size 9999
#@(#)   v0.09	11jan2021 : fileoutfull for rm suggestion
#@(#)   v0.10	24jan2021 : enabled getopt with new feature to limit to one file and Force encoding
#@(#)   v0.11 24jan2021 : additional encoders
#@(#)   v0.12 06feb2021 : IFS correction for files
#@(#)   v0.13 06mar2021 : .skip logic with fileoutfull instead of fileout + correct options -? broke all
#@(#)   v0.14 12dec2021 : .skip logic with fileoutfull with .skipffmpegconvert at end iso of begin of file
#@(#)   v0.15 12dec2021 : .skip correction when error
#@(#)   v0.16 31dec2021 : added mpeg2video format and Serie option [.skipffmpegconvert skip for file is still done]
#@(#)   v0.17 01jan2022 : print audiolines of original and correcting series output reincluding .ffmpegconvert_done output
#@(#)   v0.20 02jan2022 : auto select best audio prefer eng; 5.1 or 7.1 ; ac3 or dts
#@(#)   v0.23 07jan2022 : auto select audio for all series files (map of first was used!)
#@(#)   v0.24 12jan2022 : default no more stats output only when -p -Progress and better basename and dirname for -f
#@(#)   v0.25 08oct2022 : check if output file already exists before encoding and redo exit numbers
#@(#)   v0.26 16feb2023 : use hw accell cuda instead of cuvid leaving output to cuda (not auto) and change preset to p7 -tune hq and 10 bit p010le for hvec + better title is being preserved
#@(#)   v0.27 21feb2023 : encoding with p6 hq with a minimal quality (42 was just ok, 40 good) , used avatar(1) 4k as reference. With quality option "max 42 and cq of 40" min is now 30 but looks ok at 35(avatar)
#@(#)   v0.27 26feb2023 : Option 5sdr to allow HDR to SDR with tonemap mobius # is slow. Do not use on SDR content as it will mess up the colors.
#@(#)   v0.28 27feb2023 : use ffmpeg provide by jellyfin with cuda enabled /usr/lib/jellyfin-ffmpeg/ffmpeg. Auto-encode HDR content to SDR(5sdr|h265sdr|hvecsdr) when using 5|h265|hvec
#@(#)   v0.29 28feb2023 : use [[file].xml , [[file]].nfo or movie.nfo files to get the title before using the file_tag
#@(#)   v0.30 02mar2023 : Include /usr/lib/jellyfin-ffmpeg in PATH instead of hardcoding directory in ffmpeg command
#@(#)   v0.30 04mar2023 : Prepare for more HDR color_options use colorspace color_trc color_primaries from source "bt2020nc/bt2020/smpte2084"
#@(#)   v0.31 19mar2023 : recording ffmpeg_passes in metadata
#@(#)   v0.32 25dec2023 : Added deinterlacing [-vf yadif] option to convert old DVDs
# ##################################################################################################################################
# if using snap ffmpeg you need to make sure files are in media or home
# also by default removable-media is not connected to snap
#  to set
#    sudo snap connect ffmpeg:removable-media
#  to check
#    sudo snap connections
#
###################################################################################################################################

showHelp() {
# `cat << EOF` This means that cat should stop reading when EOF is detected
cat << EOF
Usage: ./nvidia_ffmpeg.sh -d <directory> -e <encoder>
Encode all known video files using nvidia cuvid hardware for decoding and encoding

-h,    -help,          --help                  Display help

-f,   -file,          --file                   Limit search to file partern (and use dirname for dir)

-d,    -dir,           --dir                   Directory to scan and encode

-e,    -encoder,       --encoder               Enocoder 4|h264 or 5|h265|hvec (or 5sdr|h265sdr|hvecsdr)

-q,    -quality,       --quality               Minimal encoding quality string [default : "-cq 40 -qmin 30 -qmax 42 -b:v 10M -maxrate:v 20M"]

-t,    -title,         --title                 Title for metadata title

-F,    -Force,         --Force                 Force encoding ignore .skip and encoded_by checks

-S,    -Serie,         --Serie                 Do not mark directory .skipffmpegconvert however will not ignore these

-p,    -progress       --progress              Show progress stats ["-v error -stats"]

-V,    -Verbose,       --Verbose               Verbose with set -xv

-a,    -audiomap,      --audiomap              Overwrite default audio mapping ["-map 0:a"] -- all audio

-s,    -submap,        --submap                Overwrite default subtitle mapping ["-map 0:s:m:language:dut? -map 0:s:m:language:eng? -map 0:s:m:language:fra?"] -- subtitles 3 languanges

-o,    -optionaudio,   --optionaudio           Overwrite audio and sub otpions ["-c:s copy -c:a ac3 -b:a 640k"] -- copy subs and audio in ac3 640k bitrate

-y,    -yadif,         --yadif                 Deinterlacing using yadif_cuda
EOF
# EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
}

#
#
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "help,file:,dir:,Verbose,progress,Force,Serie,title:,encoder:,quality:,audiomap:,submap:,optionaudio:,yadif" -o "hf:d:pVFSt:e:a:q:s:o:y" -a -- "$@")

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
        optfile=$(basename "$1")
        export optfile=$(printf "%q" "${optfile}")
        echo "File is ${optfile}"
        if [[ -z ${optdir} ]]
        then
            export optdir=$(dirname "$1")
            echo "Dir is ${optdir}"
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
    -p|--progress)
        export prog_options="-v error -stats"
        echo " using stats"
        ;;
    -V|--Verbose)
        export Verbose=1
        set -xv  # Set xtrace and verbose mode.
        ;;
    -t|--title)
        shift
        export opttitle=$1
        echo " title [${opttitle}] provided"
        ;;
    -e|--encoder)
        shift
        export optenc=$1
        ;;
    -q|--quality)
        shift
        export optqual=$1
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
    -y|--yadif)
        export optyadif=1
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
#####
#Default Options
###
if [[ -z ${optsub} ]]
then
    map_options_sub="-map 0:s:m:language:dut? -map 0:s:m:language:eng? -map 0:s:m:language:fra?" # subs dut or eng or fra
else
    map_options_sub=${optsub}
fi
if [[ -z ${optaud} ]]
then
    #map_options_audio="-map 0:a" #all audio
    # for now all but will look for best if map_options_audio is not set
    amapaudio="-map 0:a"
else
    map_options_audio=${optaud}
    audio_option_was_set=${optaud}
fi

if [[ -z ${optqual} ]]
then
  cq_quality="-cq 37 -qmin 30 -qmax 40 -b:v 10M -maxrate:v 20M"
else
  cq_quality=${optqual}
fi

if [[ -z ${optopta} ]]
then
    audio_subs_options="-c:s copy -c:a ac3 -b:a 640k" ## copy subs and covert audio to ac3 with 640k which is higest supported the default is 480k
else
    audio_subs_options=${optopta}
fi

if [[ -z ${prog_options} ]]
then
    prog_options="-v error"
fi

if [[ -z ${optyadif} ]]
then
    yadif4=""
    yadif5=""
else
    yadif4="yadif_cuda=0:-1:0"
    yadif5="yadif_cuda=0:-1:0,"
fi

### setting PATH to include jellyfin-ffmpeg if present
if [[ -d "/usr/lib/jellyfin-ffmpeg" ]]
then
        # put the jellyfin-ffmpeg in front and remove all other instances that already existed
        export PATH="/usr/lib/jellyfin-ffmpeg:$(sed 's#^/usr/lib/jellyfin-ffmpeg:##' <<< ${PATH} |sed 's#:/usr/lib/jellyfin-ffmpeg:#:#g' | sed 's#:/usr/lib/jellyfin-ffmpeg$##')"
        echo "PATH=${PATH}"
else
        echo "/usr/lib/jellyfin-ffmpeg isn't present cuda_tonemap might not work"
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
    5sdr|h265sdr|hvecsdr)
              k=5sdr
              ##echo "encode in 265 HDR mode"
              ;;
    *)
        echo "No encoder set use 4|h264 or 5|h265|hvec or 5hdr|h265hdr|hvechdr"
        exit 204
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
            exit 220
    fi
    if [[ -f "work_${mypid}/.skipffmpegconvert" ]] && [[ -z ${Force} ]]
    then
            echo "skip because .skipffmpegconvert"
            rm "work_${mypid}/.runningffmpegconvert"
            rm work_${mypid}
            exit 227
    fi

    if [[ -f "work_${mypid}/.skipffmpegconvert" ]]
    then
          echo "skip with force, removing .skipffmpegconvert"
          rm "work_${mypid}/.skipffmpegconvert"
    fi

    echo "Running ${mypid}" >> work_${mypid}/.runningffmpegconvert
    if [[ -z ${optfile} ]]
    then
        allfiles=`find "work_${mypid}/" -maxdepth 1 -mindepth 1 -type f -size +200M -and  -not \( -name ".*" -or -name "*.AC3.nvidia264.mkv" -or -name "*.AC3.nvidia265.mkv"  \) -and  \( -name "*.mp4" -or -name "*.mkv" -or -name "*.m2ts" -or -name "*.m4v" -or -name "*.avi" \) -print `
    else
        allfiles=`find "work_${mypid}/" -maxdepth 1 -mindepth 1 -name "${optfile}" -print `
    fi
    echo "got all files ${allfiles}"
    IFS=$'\n'
    for afile in ${allfiles}
    do
        echo "file $afile"
        decoder=""
        mkv_lines=''
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
                exit 252
            fi
            if [[ -f work_${mypid}/${fileoutfull}.skipffmpegconvert ]] && [[ -z ${Force} ]]
                        then
                                echo "skip of file requested by work_${mypid}/${fileoutfull}.skipffmpegconvert "
                                #next file
                                continue
                        fi
            mkvtitle=`ffprobe  -show_entries format "${input}"  2>&1 | grep -i "TAG:title=" | sed s/TAG:title=//`
            mkv_lines=`ffmpeg -nostdin -analyzeduration 100M -probesize 100M -i "${input}" 2>&1 | grep -v X11`
            video_lines=`echo "${mkv_lines}" | grep -e Stream | grep -e Video`
            audio_lines=`echo "${mkv_lines}" | grep -e Stream | grep -e Audio`
            #
            echo "mkvtitle:${mkvtitle}"
            #since we are looping make sure whoencoded is cleared
            whoencoded="NOOne"
            #only get first encoded_by occurence this is mkv variable which is not standard so trusting this only used by this script and leaving option to use versions later
            # info : didn't find way to insert this in an existing mkv but if needed you can use the title field of the video to insert this
            # so as work arround use :  mkvpropedit "${input}" --edit info --set "title=" --edit track:v1  --set "name=Video encoded_by ffmpeg_nvidia_hardware"
            # this script inserts the encoded_by as global variable while encoding
            whoencoded=`echo "${mkv_lines}" | grep -i encoded_by | awk 'NR==0; END{print}' | sed "s/.* \(.*\)/\1/"`
            ffmpeg_passes=`echo "${mkv_lines}" | grep -i ffmpeg_passes | awk 'NR==0; END{print}' | sed "s/.* \(.*\)/\1/"`
            (( ffmpeg_passes ++))
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
            if [[ -z ${audio_option_was_set} ]]
            then
                echo "auto select best audio ################################audio################################"
                for line in ${audio_lines}
                do
                    ((++audiostream))
                    echo "${audiostream} : ${line}"
                    part1=`echo "${line}" | cut -f1 -d','`
                    astream=`echo "${part1}" | sed "s/.*Stream[[:space:]]\#\([0-9]*\):\([0-9]*\).*/\1:\2/"`
                    alan=`echo "${part1}" | sed "s/.*Stream[[:space:]]\#[0-9]*:[0-9]*(\(...\)).*/\1/"`
                    acod=`echo "${part1}" | sed "s/.*Audio:[[:space:]]\(...\).*/\1/"`
                    part3=`echo "${line}" | cut -f3 -d','`
                    achan=`echo "${part3}" | sed "s/[[:space:]]\([0-9]*.[0-9]*\).*/\1/"`
                    ##
                    #first is taken if no other criteria is met
                    audioscore=0
                    ((++audioscore))
                    #Prefered languages
                    case ${alan} in
                            eng)
                                audioscore=$(( ${audioscore} + 10 ))
                            ;;
                    esac
                    case ${alan} in
                           dut)
                                audioscore=$(( ${audioscore} + 25 ))
                           ;;
                    esac
                    case ${alan} in
                         fre)
                                audioscore=$(( ${audioscore} + 5 ))
                           ;;
                    esac
                    # prefer ac3 over dts
                    case ${acod} in
                            ac3)
                                audioscore=$(( ${audioscore} + 3 ))
                            ;;
                            dts)
                                audioscore=$(( ${audioscore} + 2 ))
                            ;;
                    esac
                    # prefer 5.1 over 7.1 only look at
                    case ${achan} in
                            5.1)
                                audioscore=$(( ${audioscore} + 7 ))
                            ;;
                            7.1)
                            audioscore=$(( ${audioscore} + 6 ))
                            ;;
                            8.1)
                                audioscore=$(( ${audioscore} + 5 ))
                            ;;
                    esac
                    bestaudioscore[${audiostream}]=${audioscore}
                    bestaudiosstream[${audiostream}]=${astream}
                    echo "${audiostream} : ${astream} ${alan} ${acod} ${achan} score ${audioscore}"
                done
                ## look for best score
                abestscore=$(( 0 + 0 ))
                for i in ${!bestaudioscore[@]};
                do
                    #echo " ${abestscore} compared ${bestaudioscore[$i]} "
                    if [[ ${abestscore} -lt ${bestaudioscore[${i}]} ]]
                        then
                            echo "$i ${bestaudiosstream[${i}]} ${bestaudioscore[${i}]}"
                            abestscore=${bestaudioscore[${i}]}
                            amapaudio="-map ${bestaudiosstream[${i}]}"
                    fi
                done
                echo "best mapped audio is ${amapaudio}"
                map_options_audio=${amapaudio}
            fi
            echo "will look for video encoder ################################video################################"
            occ=0
            decoder="uNKowN"
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
                vcodingall=`echo "${line}" |sed "s/tv\,[[:space:]]*//" | cut -f2 -d ','| sed s/^[[:space:]]//`
                vcodinga=`echo "${vcodingall}" | sed "s/\(.*\)(\(.*\)/\1/"`
                vcodingb=`echo "${vcodingall}" | sed "s/\(.*\)(\(.*\))*/\2/" | sed "s/)//" `
                #echo "${occ} ${vstream} ${vtype} ${height} x ${width} "  >> "details/\"${fileout}\".video"
                echo "${occ} ${vstream} ${vtype} ${height} x ${width} code: ${vcodinga} ${vcodingb}"
                if [[ ${vcodinga} == "yuv420p10le" ]]
                then
                   video_HDR_cuda_format=":format=p010le"
                   if [[ ${vcodingb} == "bt2020nc/bt2020/smpte2084" ]]
                   then
                     video_is_HDR="Yes"
                     echo "Video is HDR encoded"
                     video_colorspace=`echo ${vcodingb} | cut -d'/' -f1`
                     video_color_primaries=`echo ${vcodingb} | cut -d'/' -f2`
                     video_color_trc=`echo ${vcodingb} | cut -d'/' -f3`
                     echo "HDR: colorspace:=${video_colorspace} color_trc=${video_color_trc} color_primaries=${video_color_primaries}"
                     video_HDR_color_parameters=",setparams=colorspace=${video_colorspace}:color_trc=${video_color_trc}:color_primaries=${video_color_primaries}"
                     #:format=p010le,setparams=colorspace=bt2020nc:color_trc=smpte2084:color_primaries=bt2020
                     if [[ ${k} == 5 ]]
                     then
                       echo "Overwrite 5 to 5sdr"
                       k=5sdr
                     fi
                   fi
                fi

                case ${vtype} in
                    h264)
                    decoder="-c:v h264_cuvid"
                        #found decoder stop reading video_lines
                        break
                        ;;
                    hevc)
                        decoder="-c:v hevc_cuvid"
                        #found decoder stop reading video_lines
                        break
                        ;;
                    mpeg4)
                        decoder="-c:v mpeg4_cuvid"
                        #found decoder stop reading video_lines
                        break
                        ;;
                    mpeg2video)
                        decoder="-c:v mpeg2_cuvid"
                        #found decoder stop reading video_lines
                        break
                        ;;
                    mpeg2)
                        decoder="-c:v mpeg2_cuvid"
                        #found decoder stop reading video_lines
                        break
                        ;;
                    vc1)
                        decoder="-c:v vc1_cuvid"
                        #found decoder stop reading video_lines
                        break
                        ;;
                    vp8)
                        decoder="-c:v vp8_cuvid"
                        #found decoder stop reading video_lines
                        break
                        ;;
                    vp9)
                        decoder="-c:v vp9_cuvid"
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
                        ##encoder="-threads 2 -c:V h264_nvenc -preset:V p5 -tune hq -profile:V high -rc vbr -rc-lookahead:v 30 -spatial_aq 1 -aq-strength 10 ${cq_quality}"
                        if [[ -z ${optyadif} ]]
                        then
                          videofilter=""
                        else
                          videofilter="-vf ${yadif4}"
                        fi
                        encoder="-threads 2 -c:V h264_nvenc -preset:V p5 -tune hq -profile:V high -rc vbr -rc-lookahead:v 30 ${cq_quality} ${videofilter}"
                        tagenc="nvidia264"
                        hwaccel="-hwaccel cuda"
                        hwaccelout="-init_hw_device cuda=gpu:0 -filter_hw_device gpu -hwaccel_output_format cuda"
                        joblim=1
                        ;;
                    5)
                        ##encoder="-threads 2 -c:V hevc_nvenc -preset:V p6 -tune hq -profile:V main10 -rc vbr -rc-lookahead:v 30 -spatial_aq 1 -aq-strength 10 ${cq_quality} -vf scale_cuda=format=p010le"
                        encoder="-threads 2 -c:V hevc_nvenc -preset:V p6 -tune hq -profile:V main10 -rc vbr -rc-lookahead:v 30 -spatial_aq 1 -aq-strength 10 ${cq_quality} -vf ${yadif5}scale_cuda=format=p010le"
                        tagenc="nvidia265"
                        hwaccel="-hwaccel cuda"
                        hwaccelout="-init_hw_device cuda=gpu:0 -filter_hw_device gpu -hwaccel_output_format cuda"
                        joblim=1
                        ;;
                    5sdr)
                        echo " Using ${video_HDR_cuda_format}${video_HDR_color_parameters} as scale_cuda option"
                           # old version not using cuda [tonemap_cuda ]
                           #encoder="-threads 2 -c:V hevc_nvenc -preset:V p6 -tune hq -profile:V main10 -rc vbr -rc-lookahead:v 30 -spatial_aq 1 -aq-strength 10 ${cq_quality} -vf zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=mobius:desat=0,zscale=t=bt709:m=bt709:r=tv,format=p010le"
                        videofilter="-vf ${yadif5}scale_cuda=w=-1:h=-1${video_HDR_cuda_format}${video_HDR_color_parameters},tonemap_cuda=tonemap=bt2390:desat=0:peak=0:format=p010le,setparams=colorspace=bt709:color_trc=bt709:color_primaries=bt709"
                        #encoder="-threads 2 -c:V hevc_nvenc -preset:V p6 -tune hq -profile:V main10 -rc vbr -rc-lookahead:v 30 -spatial_aq 1 -aq-strength 10 ${cq_quality} ${videofilter}"
                        encoder="-threads 2 -c:V hevc_nvenc -preset:V p6 -tune hq -profile:V main10 -rc vbr -rc-lookahead:v 30 -spatial_aq 1 -aq-strength 10 ${cq_quality} ${videofilter}"
                        tagenc="nvidia265"
                        hwaccel="-hwaccel cuda"
                        hwaccelout="-init_hw_device cuda=gpu:0 -filter_hw_device gpu -hwaccel_output_format cuda"
                        #V027 don't specify when tonemap is needed
                        #hwaccelout=""
                        #decoder=""
                        # Do not start 2 sessions as memory is limited and one tonemap session can go over 50% on GTX1050Ti
                        joblim=0
                        ;;
                     *)
                        printf "Do not have a target encoder is not possible here ABORT"
                        exit 428
            esac
            encoded_by="ffmpeg_nvidia_hardware"
            #mkvtitle="" # Removing tag title is often bogus #keep
            echo "using encoded_by ${encoded_by}"
            if [[ -z ${opttitle} ]]
            then
              info_title=`grep -soP '(?<=<title>).*?(?=</title>)' work_${mypid}/${fileout}.xml`
              if [[ ${info_title} == "" ]]
              then
                info_title=`grep -soP '(?<=<title>).*?(?=</title>)' work_${mypid}/${fileout}.nfo`
                if [[ ${info_title} == "" ]]
                then
                   info_title=`grep -soP '(?<=<title>).*?(?=</title>)' work_${mypid}/movie.nfo`
                   if [[ ${info_title} == "" ]]
                   then
                      echo " no title set using mkvtitle:${mkvtitle}"
                      meta_title=${mkvtitle}
                   else
                      echo " no title set using movie.nfo:${info_title}"
                      meta_title=${info_title}
                   fi
                else
                   echo " no title set using ${fileout}.nfo:${info_title}"
                   meta_title=${info_title}
                fi
              else
                 echo " no title set using ${fileout}.xml:${info_title}"
                 meta_title=${info_title}
              fi
            else
                meta_title=${opttitle}
            fi
            echo "using encoder ${encoder}"
            echo "using append  ${tagenc}"
            echo "using meta title ${meta_title}"
            #qualityffmpeg=$(sed 's#-##g' <<< ${cq_quality})
            qualityffmpeg="${cq_quality}"
            echo "add quality meta info ${qualityffmpeg}"
            # important use -nostdin otherwise ffmpeg will freeze when there're multiple files to encode in the same run
            # decided after testing to use only features directly supported by nvidia and leave as much as possible defaults using preset hq which is best quality with max 3 b frames (bd is same with 2)
            #command_recode=`echo "ffmpeg -nostdin ${prog_options} -analyzeduration 100M -probesize 100M ${hwaccel} {decoder} ${hwaccelout} -i \"${input}\" -metadata title=\"${meta_title}\" -metadata encoded_by=${encoded_by} ${map_options} ${encoder} ${audio_subs_options} -map_metadata 0 -movflags use_metadata_tags -max_muxing_queue_size 9999 \"work_${mypid}/${fileout}.AC3.${tagenc}.mkv\""`
            #command_recode=`echo "ffmpeg -nostdin ${prog_options} -analyzeduration 100M -probesize 100M ${hwaccel} ${decoder} ${hwaccelout} -i \"${input}\" -metadata title=\"${meta_title}\" -metadata encoded_by=${encoded_by} ${map_options} ${encoder} ${audio_subs_options} -map_metadata 0 -movflags use_metadata_tags -max_muxing_queue_size 9999 \"work_${mypid}/${fileout}.AC3.${tagenc}.mkv\""`
            #### use ffmpeg provide by jellyfin with cuda enabled /usr/lib/jellyfin-ffmpeg/ffmpeg ... rely on PATH since .030
            command_recode=`echo "ffmpeg -nostdin ${prog_options} -analyzeduration 100M -probesize 100M ${hwaccel} ${decoder} ${hwaccelout} -i \"${input}\" -metadata ffmpeg_passes=${ffmpeg_passes} -metadata ffmpeg_quality=\"${qualityffmpeg}\" -metadata title=\"${meta_title}\" -metadata encoded_by=${encoded_by} ${map_options} ${encoder} ${audio_subs_options} -map_metadata 0 -movflags use_metadata_tags -max_muxing_queue_size 9999 \"work_${mypid}/${fileout}.AC3.${tagenc}.mkv\""`
            echo "command to recode : ${command_recode}"
            # nvidia-smi encodersessions not working
            limit=`nvidia-smi | grep " C " | wc -l`
            #$echo ${limit}
            while (( limit > ${joblim} ))
            do
                echo " to many jobs running ${limit} check nvidia-smi waiting 10 min"
                # not added value to run more than 2 as encoder is already 100% with one job
                sleep 600
                limit=`nvidia-smi | grep " C " | wc -l`
            done
            echo " ok to start a new only running ${limit} jobs nvidia-smi type C"
            echo "  check if output file \"work_${mypid}/${fileout}.AC3.${tagenc}.mkv\" doesn't exists"
                if [[ -f "work_${mypid}/${fileout}.AC3.${tagenc}.mkv" ]]
                then
                  echo "Aborting since output file exists"
                  rm "work_${mypid}/.runningffmpegconvert"
                  rm work_${mypid}
                  exit 462
                fi
            echo "starting encoding ################################encode################################"
            eval ${command_recode}
            cresult=$?
            if [[ ${cresult} == 0 ]]
            then
                echo "ffmpeg success : work_${mypid}/${fileout}.AC3.${tagenc}.mkv"
                filesizenew=$(stat -c%s "work_${mypid}/${fileout}.AC3.${tagenc}.mkv")
                filesizeold=$(stat -c%s "${input}")
                echo "Size of new ${filesizenew} vs old ${filesizeold}"
                ### if (a > b ) is similar as if [ "$a" -gt "$b" ]
                if (( filesizenew > filesizeold )); then
                        echo "nope new file bigger [[ Force = ${Force} ]] ${input} ################################SizeNoK################################"
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
                echo "post processing finding str ################################post################################"
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
                echo "'${inputdir}/${fileoutfull}_converted_${tagenc}'" >> conversion_completed
                now=$(date)
                echo "on ${now} completed ${fileout} : ${tagenc}'" >> "work_${mypid}/.ffmpegconvert_done"
                echo " Audio was ${audio_lines}" >> "work_${mypid}/.ffmpegconvert_done"
                echo " Audio selected ${map_options_audio}" >> "work_${mypid}/.ffmpegconvert_done"
                echo " ####### Audio was ${audio_lines} #######"
                echo " ####### Audio selected ${map_options_audio} #######"
                echo "will do : ${mvcmd}"
                eval ${mvcmd}
                echo "###################TAGS###################"
                probe_command=`echo "ffprobe -v quiet -show_format \"work_${mypid}/${fileout}.AC3.${tagenc}.mkv\""`
                eval ${probe_command}
                echo "###################TAGS###################"
            else
                echo "Error ffmpeg result ${cresult}"
                if [[ -z ${Forceserie} ]]
                then
                    echo "Reason ffmpeg error '${inputdir}' file ${fileout} : ${cresult}" >> "work_${mypid}/.skipffmpegconvert"
                fi
                echo "Reason ffmpeg error '${inputdir}' file ${fileout} : ${cresult}" >> "work_${mypid}/${fileoutfull}.skipffmpegconvert"
                echo "Reason ffmpeg error '${inputdir}' ${fileoutfull}  ${cresult}" >> conversion_failed
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
rm work_${mypid}