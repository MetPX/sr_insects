#!/bin/bash

flow_test_name="`basename pwd`"

# parse arguments
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -s|--skip_summaries)
    skip_summaries=true
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}"

. ./flow_include.sh
countall

function summarize_performance {
    path="$LOGDIR"/$1
    shift
    pattern=$1
    shift
    for i in $* ; do
       best_fn=''
       printf "\n\t$i\n\n"
       for j in ${path}_${i}_*.log; do
           msg="`grep ${pattern} ${j} | tail -1`"
           if [[ -z "$msg" ]]; then
               continue
           fi
           fn=`echo $(basename ${j}) | awk -F'.' '{print $3}'`
           if [[ -z "$fn" ]]; then
               best_fn=`echo $(basename ${j})`
               echo "`basename $j` ${msg}"
           elif [[ -z "$best_fn" ]]; then
               echo "`basename $j` ${msg}"
           fi
       done
    done
}

function summarize_logs {
    printf "\n$1 Summary:\n"
    input_size=${#1}
    fcl="$LOGDIR"/flowcheck_$1_logged.txt
    msg_counts=`grep -h -o "\[$1\] *.*" "$LOGDIR"/*.log | sort | uniq -c -w"$((input_size+20))" | sort -n -r`
    echo '' > ${fcl}

    if [[ -z $msg_counts ]]; then
       echo NO $1S IN LOGS
    else
       backup_ifs=$IFS
       IFS=$'\n'
       for msg_line in $msg_counts; do
            count=`echo ${msg_line} | awk '{print $1}'`
            msg=`echo ${msg_line} | sed "s/^ *[0-9]* \[$1\] *//g"`
            pattern="\[$1\] *${msg}"
            filelist=($(grep -l ${pattern::$((input_size + 22))} "$LOGDIR"/*.log))
            if [[ ${filelist[@]} ]]; then
                first_filename=`basename ${filelist[0]} | sed 's/ /\n/g' | sed 's|.*\/||g' | sed 's/_[0-9][0-9]\.log\|.log//g' | uniq`
                files_nb=${#filelist[@]}
                echo "  ${count}"$'\u2620'"${first_filename}"$'\u2620'"(${files_nb} file)"$'\u2620'"`echo ${msg_line} | sed "s/^ *[0-9]* //g"`" >> ${fcl}
                echo ${filelist[@]} | sed 's/^//g' | sed 's/ \//\n\//g' >> ${fcl}
                echo -e >> ${fcl}
            fi
       done
       IFS=${backup_ifs}
       result=`grep -c $1 ${fcl}`
       if [[ ${result} -gt 10 ]]; then
           grep $1 ${fcl} | head | column -t -s $'\u2620' | cut -c -130
           echo
           echo "More than 10 TYPES OF $1S found... for the rest, have a look at $fcl for details"
       else
           grep $1 ${fcl} | column -t -s $'\u2620' | cut -c -130
       fi
    fi
}

if [[ -z "$skip_summaries" ]]; then
    # PAS performance summaries
    printf "\nDownload Performance Summaries:\tLOGDIR=$LOGDIR\n"
    #summarize_performance sr_shovel msg_total: t_dd1 t_dd2
    #summarize_performance sr_subscribe file_total: cdnld_f21 amqp_f30 cfile_f44 u_sftp_f60 ftp_f70 q_f71

    summarize_logs ERROR
    summarize_logs WARNING
fi

passedno=0
tno=0

printf "\t\tTEST RESULTS\n\n"

calcres ${staticfilecount} ${totpollftp} "files sr_polled by FTP (${totpollftp}) should be same as in sample\t (${staticfilecount})"
calcres ${staticfilecount} ${totpollsftp} "files sr_polled by SFTP (${totpollsftp}) should be same as in sample\t (${staticfilecount})"
calcres ${totpollftp}    ${totsubftp} "sr_subscribe\t (${totsubftp}) should as many as polled (FTP)\t (${totpollftp})"
calcres ${totpollsftp}    ${totsubsftp} "sr_subscribe\t (${totsubsftp}) should as many as polled (SFTP)\t (${totpollsftp})"

tallyres ${tno} ${passedno} "Overall ${flow_test_name} ${passedno} of ${tno} passed (sample size: $staticfilecount) !"
results=$?

if (("${missed_dispositions}">0)); then
   # PAS missed_dispositions means definite Sarra bug, very serious.
   echo "Please review $missedreport"
   results=1
fi
echo

timestamp_summarize

exit ${results}
