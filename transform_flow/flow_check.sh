#!/bin/bash

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
    summarize_performance ${LGPFX}sarra msg_total: download_f20
    summarize_performance ${LGPFX}subscribe file_total: u_sftp_f60 ftp_f70 q_f71

    echo
    # MG shows retries
    echo

    if [[ ! "$SARRA_LIB" ]]; then
       echo NB retries for sr_sender    `grep Retrying "$LOGDIR"/${LGPFX}sender*.log | wc -l`
    else
       echo NB retries for "$SARRA_LIB"/sr_sender.py    `grep Retrying "$LOGDIR"/${LGPFX}sender*.log | wc -l`
    fi

    summarize_logs ERROR
    summarize_logs WARNING
fi

passedno=0
tno=0

if [[ "${totshovel2}" -gt "${totshovel1}" ]]; then
   maxshovel=${totshovel2}
else 
   maxshovel=${totshovel1}
fi
printf "\n\tMaximum of the shovels is: ${maxshovel}\n\n"

printf "\t\tTEST RESULTS\n\n"

tot2shov=$(( ${totshovel1} + ${totshovel2} ))

tot2stat=$(( 2*${staticfilecount} ))

echo "                 | static post |"
#calcres "${staticfilecount}" "${totshovel2}" "sr_post\t count of posted files (${totshovel2}) should be same those in the static data directory\t (${staticfilecount})"
calcres "${totshovel1}" "${totshovel2}" "sr_post\t (${totshovel1}) t_dd1 should have the same number of items as t_dd2\t (${totshovel2})"
echo "                 | sarra download and transform a subset |"
calcres "${totsarx}" "${tot2stat}" "sr_sarra\t (${totsarx}) should receive the same number of items as both static file trees (${tot2stat})"
calcres "${totsarp}" "${staticfilecount}" "sr_sarra\t (${totsarp}) should publish the same number of items as the data directory\t (${staticfilecount})"
calcres "${totrejected}" "${staticfilecount}" "sr_sarra\t (${totrejected}) should reject the same number of items as static tree\t (${staticfilecount})"
calcres "${totsubu}" "${totsent}"  "sr_subscribe u_sftp_f60 (${totsubu}) should download same number of items as sr_sender (${totsent})"
calcres "${totsubcp}" "${totsent}" "sr_subscribe cp_f61\t (${totsubcp}) should download same number of items as sr_sender (${totsent})"
echo "                 | poll       routing |"
calcres "${totpoll1}" "${totsent}" "sr_poll f62\t (${totpoll1}) should publish same number of items of sr_sender sent\t (${totsent})"
calcres "${totsubq}" "${totpoll1}" "sr_subscribe q_f71\t (${totsubq}) should download same number of items as sr_poll test1_f62 (${totpoll1})"
echo "                 | flow_post  routing |"
calcres "${totpost1}" "${totsent}" "sr_post test2_f61\t (${totpost1}) should have the same number of items of sr_sender \t (${totsent})"
calcres "${totsubftp}" "${totpost1}" "sr_subscribe ftp_f70\t (${totsubftp}) should have the same number of items as sr_post test2_f61 (${totpost1})"
calcres "${totpost1}" "${totshimpost1}" "sr_post test2_f61\t (${totpost1}) should have about the same number of items as shim_f63\t (${totshimpost1})"
zerowanted "${missed_dispositions}" "${maxshovel}" "messages received that we don't know what happened."

# these almost never are the same, and it's a problem with the post test. so failures here almost always false negative.
#calcres ${totpost1} ${totsubu} "post test2_f61 ${totpost1} and subscribe u_sftp_f60 ${totsubu} run together. Should be about the same."


tallyres "${tno}" "${passedno}" "Overall ${passedno} of ${tno} passed (sample size: $staticfilecount) !"
results=$?

if (("${missed_dispositions}">0)); then
   # PAS missed_dispositions means definite Sarra bug, very serious.
   echo "Please review $missedreport"
   results=1
fi
echo

exit ${results}
