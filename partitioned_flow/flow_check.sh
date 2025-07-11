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

function checktree {
  tree=$1
  printf "checking +${tree}+\n"
  SUMDIR=${LOGDIR}/sums
  if [ ! -d $SUMDIR ]; then
      mkdir $SUMDIR
  fi

  report=${SUMDIR}/`basename ${tree}`.txt
  #if [ ! -f ${report} ]; then
  (cd ${tree}; find . \! -type d | xargs md5sum ) > ${report}
  #fi

}

function logPermCheck {
    tno=$((${tno}+1))

    #looking into the configs for chmod_log commands if they exist
    perms="`grep chmod_log config -r`"
    file1=`grep chmod_log config -r | cut -f2 -d"/"`
    file2=`grep chmod_log config -r | cut -f3 -d"/" | cut -f1 -d"."`

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

function comparetree {

  tno=$((${tno}+1))
  SUMDIR=${LOGDIR}/sums
  diff ${SUMDIR}/${1}.txt ${SUMDIR}/${2}.txt >/dev/null 2>&1 
  result=$?

  if [ $result -gt 0 ]; then
     printf "test %d FAILURE: compare contents of ${1} and ${2} differ\n" $tno
  else
     printf "test %d success: compare contents of ${1} and ${2} are the same\n" $tno
     passedno=$((${passedno}+1))
 fi
  
}

printf "checking trees...\n"
checktree ../samples/data
checktree ${testdocroot}/downloaded_by_sub_amqp
checktree ${testdocroot}/downloaded_by_sub_cp
checktree ${testdocroot}/downloaded_by_sub_rabbitmqtt
checktree ${testdocroot}/downloaded_by_sub_u
checktree ${testdocroot}/posted_by_shim
checktree ${testdocroot}/recd_by_srpoll_test1
checktree ${testdocroot}/sent_by_tsource2send
checktree ${testdocroot}/mirror/linked_by_shim
checktree ${testdocroot}/cfile
checktree ${testdocroot}/cfr


if [[ -z "$skip_summaries" ]]; then
    # PAS performance summaries
    printf "\nDownload Performance Summaries:\tLOGDIR=$LOGDIR\n"
    summarize_performance shovel msg_total: rabbitmqtt_f22
    summarize_performance subscribe file_total: cdnld_f21 amqp_f30 cfile_f44 u_sftp_f60 ftp_f70 q_f71

    echo
    # MG shows retries
    echo

    if [[ ! "$SARRA_LIB" ]]; then
       echo NB retries for subscribe amqp_f30 `grep Retrying "$LOGDIR"/subscribe_amqp_f30*.log | wc -l`
       echo NB retries for sender    `grep Retrying "$LOGDIR"/sender*.log | wc -l`
    else
       echo NB retries for "$SARRA_LIB"/subscribe.py amqp_f30 `grep Retrying "$LOGDIR"/subscribe_amqp_f30*.log | wc -l`
       echo NB retries for "$SARRA_LIB"/sender.py    `grep Retrying "$LOGDIR"/sender*.log | wc -l`
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

logPermCheck

echo "                 | content of subdirs of ${testdocroot} |"
comparetree downloaded_by_sub_amqp downloaded_by_sub_cp
comparetree downloaded_by_sub_cp downloaded_by_sub_rabbitmqtt
comparetree downloaded_by_sub_rabbitmqtt downloaded_by_sub_u
comparetree downloaded_by_sub_u posted_by_shim
comparetree downloaded_by_sub_amqp linked_by_shim
comparetree posted_by_shim sent_by_tsource2send

if [ "${SKIP_KNOWN_BAD}" ]; then
   echo "skipping one known bad v2 comparison."
else
   comparetree downloaded_by_sub_amqp cfile
fi 
comparetree cfile cfr

echo "broker state:"
if [[ ${messages_unacked} > 0 ]] || [[ ${messages_ready} > 0 ]]; then

   echo "rabbitmq broker message anomalies\n"
   rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} list queues name messages_ready messages_unacknowledged | awk ' BEGIN {t=0; } (NR<3) {print;} (NR > 2)  && /_f[0-9][0-9]/ { t+=$4; if ( $4 > 0 || $6 > 0) print; }; '

fi



tot2shov=$(( ${totshovel1} + ${totshovel2} ))
t4=$(( ${totfileamqp}*4 ))

justfilecount=$(( ${staticfilecount} - ${staticdircount} ))
echo " source tree: total:${staticfilecount} files: ${justfilecount} directories:${staticdircount} rejected:${rejectfilecount}"

echo "                 | dd.weather routing |"
#calcres "${staticfilecount}" "${totshovel2}" "post\t count of posted files (${totshovel2}) should be same those in the static data directory\t (${staticfilecount})"
#calcres "${rejectfilecount}" "${totshovel2rej}" "post\t count of rejected files (${totshovel2rej}) should be same those in the static data directory\t (${rejectfilecount})"
calcres "${totshovel1}" "${totshovel2}" "post\t (${totshovel1}) t_dd1 should have the same number of items as t_dd2\t (${totshovel2})"
calcres "${totsarx}" "${tot2shov}" "sarra\t (${totsarx}) should receive the same number of items as both post\t (${tot2shov})"
calcres "${totsarp}" "${totshovel1}" "sarra\t (${totsarp}) should publish the same number of items as one post\t (${totshovel1})"
calcres "${totwinnowed}" "${totshovel1}" "sarra\t (${totwinnowed}) should winnow the same number of items as one post\t (${totshovel1})"


if [ "${SKIP_KNOWN_BAD}" ]; then
    echo "skipping known bad subscriber check."
else
    calcres "${totfileamqp}" "${staticfilecount}" "subscribe\t (${totfileamqp}) should rx the same number of items as in static tree\t (${staticfilecount})"
fi
echo "                 | watch      routing |"
calcres "${totwatch}" "${totfileamqp}"         "watch\t\t (${totwatch}) should be the same as subscribe amqp_f30\t\t  (${totfileamqp})"
calcres "${totsent}" "${totwatch}" "sender\t\t (${totsent}) should publish the same number of items as watch  (${totwatch})"
calcres "${totsubrmqtt}" "${totwatch}" "rabbitmqtt\t\t (${totsubrmqtt}) should download same number of items as watch  (${totwatch})"
calcres "${totsubu}" "${totsent}"  "subscribe u_sftp_f60 (${totsubu}) should download same number of items as sender (${totsent})"
calcres "${totsubcp}" "${totsent}" "subscribe cp_f61\t (${totsubcp}) should download same number of items as sender (${totsent})"
echo "                 | poll       routing |"
calcres "${totpoll1}" "${totsent}" "poll sftp_f62\t (${totpoll1}) should publish same number of items of sender sent\t (${totsent})"
if [ "${totpoll_mirrored}" ]; then
    calcres "${totpoll1}" "${totpoll_mirrored}" "poll sftp_f63\t (${totpoll_mirrored}) should see the same number of items as poll sftp_f62 posted\t (${totsent})"
fi
calcres "${totsubq}" "${totpoll1}" "subscribe q_f71\t (${totsubq}) should download same number of items as poll test1_f62 (${totpoll1})"
echo "                 | flow_post  routing |"
calcres "${totpost1}" "${totfilesent}" "post test2_f61\t (${totpost1}) should have the same number of files of sender \t (${totfilesent})"
calcres "${totsubftp}" "${totpost1}" "subscribe ftp_f70\t (${totsubftp}) should have the same number of items as post test2_f61 (${totpost1})"

if [[ "${sarra_py_version}" > "3.00.25" ]]; then
  
    calcres "${totpost1}" "${totfileshimpost1}" "post test2_f61\t (${totpost1}) should post about the same number of files as shim_f63\t (${totfileshimpost1})"
    calcres "${totpost1}" "${totlinkshimpost1}" "post test2_f61\t (${totpost1}) should post about the same number of links as shim_f63\t (${totlinkshimpost1})"
    # FIXME: the following test should be zero, but it isn't... in flakey it is zero, which is correct... very confusing. 
    #calcres "${staticdircount}" "${totlinkdirshimpost1}" "static tree\t (${staticdircount}) should have a post for every linked directories by shim_f63\t (${totlinkdirshimpost1})"
    twostaticdir=$(( ${staticdircount} * 2 ))
    calcres "${twostaticdir}" "${totdirshimpost1}" "static tree\t (${staticdircount}) directories should be posted twice: for 1st copy and linked_dir by shim_f63\t (${totdirshimpost1})"
else
    doubletotpost=$(( ${totpost1}*2 ))
    calcres "${doubletotpost}" "${totshimpost1}" "post test2_f61\t (${totpost1}) should have about half the number of items as shim_f63\t (${totshimpost1})"
fi

echo "                 | py infos   routing |"
#zerowanted "${totauditkills}" "${CONFIG_COUNT}" "sr_audit should not have killed anything. It killed ${totauditkills} processes" 
zerowanted "${missed_dispositions}" "${maxshovel}" "messages received that we don't know what happened."
# check removed because of issue #294
#calcres ${totshortened} ${totfileamqp} \
#   "count of truncated headers (${totshortened}) and subscribed messages (${totmsgamqp}) should have about the same number of items"

# these almost never are the same, and it's a problem with the post test. so failures here almost always false negative.
#calcres ${totpost1} ${totsubu} "post test2_f61 ${totpost1} and subscribe u_sftp_f60 ${totsubu} run together. Should be about the same."

# because of accept/reject filters, these numbers are never similar, so these tests are wrong.
# tallyres ${totcpelle04r} ${totcpelle04p} "pump pelle_dd1_f04 (c shovel) should publish (${totcpelle04p}) as many messages as are received (${totcpelle04r})"
# tallyres ${totcpelle05r} ${totcpelle05p} "pump pelle_dd2_f05 (c shovel) should publish (${totcpelle05p}) as many messages as are received (${totcpelle05r})"

if [[ "$C_ALSO" || -d "$SARRAC_LIB" ]]; then

echo "                 | C          routing |"
  calcres  ${totcpelle04p} ${totcpelle05p} "cpost both pelles should post the same number of messages (${totcpelle05p}) (${totcpelle04p})"

  totcvan=$(( ${totcvan14p} + ${totcvan15p} ))
  calcres  ${totcvan} ${totcdnld} "cdnld_f21 subscribe downloaded ($totcdnld) the same number of files that was published by both van_14 and van_15 ($totcvan)"
  t5=$(( $totcveille / 2 ))
  calcres  "${totcveille}" "${totcdnld}" "veille_f34 should post as many files ($totcveille) as subscribe cdnld_f21 downloaded ($totcdnld)"
  calcres  "${totcveille}" "${totcfile}" "veille_f34 should post as many files ($totcveille) as subscribe cfile_f44 downloaded ($totcfile)"

fi

if [ "$MQP" == "amqp" ]; then
  zerowanted  "${messages_unacked}" "${maxshovel}" "there should be no unacknowledged messages left, but there are ${messages_unacked}"
  zerowanted  "${messages_ready}" "${maxshovel}" "there should be no messages ready to be consumed but there are ${messages_ready}"
fi


echo "Overall ${flow_test_name} ${passedno} of ${tno} passed (sample size: $staticfilecount) !"

#tallyres "${tno}" "${passedno}" "Overall ${passedno} of ${tno} passed (sample size: $staticfilecount) !"

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

timestamp_summarize

exit ${results}
