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
           msg="`grep -a ${pattern} ${j} | tail -1`"
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
    msg_counts=`grep -a -h -o "\[$1\] *.*" "$LOGDIR"/*.log | sort | uniq -c -w"$((input_size+20))" | sort -n -r`
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
            filelist=($(grep -a -l ${pattern::$((input_size + 22))} "$LOGDIR"/*.log))
            if [[ ${filelist[@]} ]]; then
                first_filename=`basename ${filelist[0]} | sed 's/ /\n/g' | sed 's|.*\/||g' | sed 's/_[0-9][0-9]\.log\|.log//g' | uniq`
                files_nb=${#filelist[@]}
                echo "  ${count}"$'\u2620'"${first_filename}"$'\u2620'"(${files_nb} file)"$'\u2620'"`echo ${msg_line} | sed "s/^ *[0-9]* //g"`" >> ${fcl}
                echo ${filelist[@]} | sed 's/^//g' | sed 's/ \//\n\//g' >> ${fcl}
                echo -e >> ${fcl}
            fi
       done
       IFS=${backup_ifs}
       result=`grep -a -c $1 ${fcl}`
       if [[ ${result} -gt 10 ]]; then
           grep -a $1 ${fcl} | head | column -t -s $'\u2620' | cut -c -130
           echo
           echo "More than 10 TYPES OF $1S found... for the rest, have a look at $fcl for details"
       else
           grep -a $1 ${fcl} | column -t -s $'\u2620' | cut -c -130
       fi
    fi
}

function checktree_md5sum {
  tree=$1
  printf "checking +${tree}+\n"
  SUMDIR=${LOGDIR}/sums
  if [ ! -d $SUMDIR ]; then
      mkdir $SUMDIR
  fi

  report=${SUMDIR}/`basename ${tree}`_md5.txt
  #if [ ! -f ${report} ]; then
  (cd ${tree}; find . \! -type d | xargs md5sum ) | sort > ${report}
  #fi

}

function checktree_fn {
  tree=$1
  printf "checking +${tree}+\n"
  SUMDIR=${LOGDIR}/fn
  if [ ! -d $SUMDIR ]; then
      mkdir $SUMDIR
  fi

  report=${SUMDIR}/`basename ${tree}`_fn.txt
  #if [ ! -f ${report} ]; then
  (cd ${tree}; find . \! -type d | awk '{print $NF}' | cut -d '/' -f6- | cut -d '_' -f-5 ) | sort > ${report}
  #fi

}

function logPermCheck {
    tno=$((${tno}+1))

    #looking into the configs for chmod_log commands if they exist
    perms="`grep -a chmod_log config -r`"
    file1=`grep -a chmod_log config -r | cut -f2 -d"/"`
    file2=`grep -a chmod_log config -r | cut -f3 -d"/" | cut -f1 -d"."`

    #finding the log related to the config file
    if [ "${sarra_py_version:0:1}" == "3" ]; then
        path=$HOME/.cache/sr3/log/"$file1"_*.log
    else
        path=$HOME/.cache/sarra/log/sr_"$file1"_*.log
    fi
    #printf "$path \n"

    #checking if the perms from the config is reflected in the file
    fileperms=`stat -c "%a %n" $path`
    if [[ "$fileperms" == *"${perms: -3}"* ]]; then
        printf "test %d success: Log perms confirmed\n" $tno
        passedno=$((${passedno}+1))
    else
        printf "test %d FAILURE: Log perms test failed.\n" $tno
    fi
}

function comparetree_md5 {

  tno=$((${tno}+1))
  SUMDIR=${LOGDIR}/sums
  diff ${SUMDIR}/${1}_md5.txt ${SUMDIR}/${2}_md5.txt >/dev/null 2>&1 
  result=$?

  if [ $result -gt 0 ]; then
     printf "test %d FAILURE: compare contents of ${1}_md5 and ${2}_md5 differ\n" $tno
  else
     printf "test %d success: compare contents of ${1}_md5 and ${2}_md5 are the same\n" $tno
     passedno=$((${passedno}+1))
 fi
  
}

function comparetree_fn {

  tno=$((${tno}+1))
  SUMDIR=${LOGDIR}/fn
  diff ${SUMDIR}/${1}_fn.txt ${SUMDIR}/${2}_fn.txt >/dev/null 2>&1 
  result=$?

  if [ $result -gt 0 ]; then
     printf "test %d FAILURE: compare contents of ${1}_fn and ${2}_fn differ\n" $tno
  else
     printf "test %d success: compare contents of ${1}_fn and ${2}_fn are the same\n" $tno
     passedno=$((${passedno}+1))
 fi
  
}

printf "checking trees...\n"
# Remove special characters
# for bulletinsdir in bulletins_to_{download,post,send} bulletins_subscribe
# do
# 	files2sed=$(find ${testdocroot}/$bulletinsdir -type f )
# 	for bulletin in $files2sed
# 	do
# 		sed -i $'s/^M//g' $bulletin
# 	done
# done

checktree_md5sum ${testdocroot}/bulletins_subscribe
checktree_md5sum ${testdocroot}/bulletins_to_send

checktree_fn ${testdocroot}/bulletins_to_download
checktree_fn ${testdocroot}/bulletins_subscribe
checktree_fn ${testdocroot}/bulletins_to_send




if [[ -z "$skip_summaries" ]]; then
    # PAS performance summaries
    printf "\nDownload Performance Summaries:\tLOGDIR=$LOGDIR\n"
    summarize_performance ${LGPFX}sarra msg_total: get_from-watch_f02
    summarize_performance ${LGPFX}flow msg_total: amserver-flow_f01
    summarize_performance ${LGPFX}subscribe file_total: bulletin_subscribe_f05

    echo
    echo

    if [[ ! "$SARRA_LIB" ]]; then
       echo NB retries for ${LGPFX}sarra    `grep -a Retrying "$LOGDIR"/${LGPFX}sarra*.log | wc -l`
       echo NB retries for ${LGPFX}flow    `grep -a Retrying "$LOGDIR"/${LGPFX}flow*.log | wc -l`
       echo NB retries for ${LGPFX}subscribe `grep -a Retrying "$LOGDIR"/${LGPFX}subscribe*.log | wc -l`
    # else
    #    echo NB retries for "$SARRA_LIB"/${LGPFX}subscribe.py amqp_f30 `grep -a Retrying "$LOGDIR"/${LGPFX}subscribe_amqp_f30*.log | wc -l`
    #    echo NB retries for "$SARRA_LIB"/${LGPFX}sender.py    `grep -a Retrying "$LOGDIR"/${LGPFX}sender*.log | wc -l`
    fi

    summarize_logs ERROR
    summarize_logs WARNING
fi


passedno=0
tno=0


printf "\t\tTEST RESULTS\n\n"

logPermCheck

echo "                 | content of subdirs of ${testdocroot} |"
# We can't compare with the tree that we download from the sarra because the station mappings is missing entries inside of the flow
# So we can't compare the filenames as a lot of them are different.
comparetree_md5 bulletins_to_send bulletins_subscribe
comparetree_fn bulletins_to_send bulletins_subscribe

echo "broker state:"
if [[ ${messages_unacked} > 0 ]] || [[ ${messages_ready} > 0 ]]; then

   echo "rabbitmq broker message anomalies\n"
   rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} list queues name messages_ready messages_unacknowledged | awk ' BEGIN {t=0; } (NR<3) {print;} (NR > 2)  && /_f[0-9][0-9]/ { t+=$4; if ( $4 > 0 || $6 > 0) print; }; '

fi

echo "                 | Message posting |"
calcres "${totwatch}" "${totsarx}"         "${LGPFX}watch\t\t (${totwatch}) should post be the same as the messages filtered by the sarra\t\t  (${totsarx})"
calcres "${totsarp}" "${totsentx}" "${LGPFX}sarra\t\t (${totsarp}) should publish the same number of items as ${LGPFX}sender accepts  (${totsentx})"
calcres "${totsentx}" "${totflowp}" "sender\t\t (${totsentx}) should post same number of items as ${LGPFX}flow posts  (${totflowp})"
echo "                 | Downloaded files |"
calcres "${totsard}" "${totflowd}" "${LGPFX}sarra\t (${totsard}) should download same number of files as ${LGPFX}flow downloads\t (${totflowd})"
calcres "${totflowd}" "${totsub}" "${LGPFX}flow\t (${totflowd}) should download same number of files as ${LGPFX}subscribe downloads (${totsub})"
zerowanted "${missed_dispositions}" "${bulletin_count}" "messages received that we don't know what happened."

if [ "$MQP" == "amqp" ]; then
    zerowanted  "${messages_unacked}" "${bulletin_count}" "there should be no unacknowledged messages left, but there are ${messages_unacked}"
    zerowanted  "${messages_ready}" "${bulletin_count}" "there should be no messages ready to be consumed but there are ${messages_ready}"
fi

echo "Overall ${flow_test_name} ${passedno} of ${tno} passed (sample size: $staticfilecount) !"


if [ "${passedno}" -gt 0 -a "${passedno}" -eq "${tno}" ]; then
   results=0
else
   results=$(( "${tno}"-"${passedno}" ))
fi

if [[ "${missed_dispositions}" -gt 0 ]]; then
   # PAS missed_dispositions means definite Sarra bug, very serious.
   echo "Please review $missedreport"
   results=1
fi
echo

exit ${results}
