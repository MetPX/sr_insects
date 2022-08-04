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

if [[ -z "$skip_summaries" ]]; then
    # PAS performance summaries
    printf "\nDownload Performance Summaries:\tLOGDIR=$LOGDIR\n"
    summarize_performance ${LGPFX}shovel msg_total: t_dd1 t_dd2
    summarize_performance ${LGPFX}subscribe file_total: cdnld_f21 amqp_f30 cfile_f44 u_sftp_f60 ftp_f70 q_f71

    echo
    # MG shows retries
    echo

    if [[ ! "$SARRA_LIB" ]]; then
       echo NB retries for sr_subscribe amqp_f30 `grep Retrying "$LOGDIR"/${LGPFX}subscribe_amqp_f30*.log | wc -l`
       echo NB retries for sr_sender    `grep Retrying "$LOGDIR"/${LGPFX}sender*.log | wc -l`
    else
       echo NB retries for "$SARRA_LIB"/${LGPFX}subscribe.py amqp_f30 `grep Retrying "$LOGDIR"/${LGPFX}subscribe_amqp_f30*.log | wc -l`
       echo NB retries for "$SARRA_LIB"/${LGPFX}sender.py    `grep Retrying "$LOGDIR"/${LGPFX}sender*.log | wc -l`
    fi

    summarize_logs ERROR
    summarize_logs WARNING
fi

if [[ ${messages_unacked} > 0 ]] || [[ ${messages_ready} > 0 ]]; then
   
   echo "rabbitmq broker message anomalies\n"
   rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} list queues name messages_ready messages_unacknowledged | awk ' BEGIN {t=0; } (NR<3) {print;} (NR > 2)  && /_f[0-9][0-9]/ { t+=$4; if ( $4 > 0 || $6 > 0) print; }; '

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
t4=$(( ${totfileamqp}*4 ))
t5=$(( ${totsent}/2 ))
t6=$(( ${totfileamqp}*2 ))

echo "                 | dd.weather routing |"
calcres "${totshovel1}" "${totshovel2}" "${LGPFX}shovel (totshovel1)\t (${totshovel1}) t_dd1 should have the same number of items as t_dd2\t (${totshovel2})"
calcres "${totwinnow}"  "${tot2shov}"   "${LGPFX}winnow (totwinnow)\t (${totwinnow}) should have the same of the number of items of shovels\t (${tot2shov})"
calcres "${totsarp}"   "${totwinpost}" "${LGPFX}sarra (totsarp)\t (${totsarp}) should have the same number of items as winnows'post\t (${totwinpost})"
# since v2.20.04b3... the time comparison is working properly, and subscribe is rejecting unmodified files.
# so this test now... correctly... fails.  commenting out for now.
#calcres ${totfileamqp}   ${totsarp}    "${LGPFX}subscribe\t (${totfileamqp}) should have the same number of items as sarra\t\t (${totsarp})"
echo "                 | watch      routing |"


if [ "${V2_SKIP_KNOWN_BAD}" ]; then
   puf=9 # pclean_unlink_factor (how many files are created and unlinked per file downloaded.)
   t8=$(( ${totfileamqp}*${puf} ))
   calcres ${totremoved}    ${t8} "${LGPFX}shovel pclean_f92\t (${totremoved}) should have removed ${puf} times the number of files downloaded\t (${totfileamqp})"
fi
calcres "${totwatch}"   "${t4}"         "${LGPFX}watch\t\t (${totwatch}) should be 4 times subscribe amqp_f30\t\t  (${totfileamqp})"
calcres "${totfileamqp}"   "${totwatchnormal}"         "amqp_f30 subscription (totfileamqp)\t\t (${totfileamqp}) should match totwatchnormal\t  (${totwatchnormal})"
calcres "${t6}" "${totwatchremoved}" "watch rm's (totwatchremove) (${totwatchremoved}) should be t6=2*totfileamqp (${t6})"
printf "\n\twatch breakdown: totwatchhlinked: %4d totwatchslinked: %4d totwatchmoved: %4d\n" "${totwatchhlinked}" "${totwatchslinked}" "${totwatchmoved}"

printf "\t\t\t totwatchremoved: %4d  totwatchnormal: %4d   totwatchall: %4d\n"  "${totwatchremoved}" "${totwatchnormal}" "${totwatchall}"
calcres "${totwatchhlinked}" "${totwatchslinked}" "totwatchhlinked\t (${totwatchhlinked}) should match symlinkes (totwatchslinked) \t  (${totwatchslinked})"
#calcres "${totwatchmoved}" "${totwatchhlinked}" "watchmoved (${totwatchmoved}) should be same as number watchhlinked (${totwatchhlinked})"
calcres "${totwatchremoved}" "${t6}" "watchremoved \t\t (${totwatchremoved}) should 2x files downloaded watchslinked \t  (${totfileamqp})"
#calcres "${totwatchnormal}" "${totwatchslinked}" "watchnormal (${totwatchnormal}) should be same as number watchslinked (${totwatchslinked})"
#calcres "${totwatchall}" "${totwatch}" "watchremoved (${totwatchall}) should be same as number totwatch (${totwatch})"
calcres "${totsent}"    "${totwatch}"   "${LGPFX}sender (totsent)\t (${totsent}) should have the same number of items as ${LGPFX}watch  (${totwatch})"

printf "\n\tsend breakdown: totsendhlinked: %4d totsendslinked: %4d totsendmoved: %4d\n" "${totsendhlinked}" "${totsendslinked}" "${totsendmoved}"
printf "\t\t\t totsendremoved: %4d  totsendnormal: %4d   totsendall: %4d\n"  "${totsendremoved}" "${totsendnormal}" "${totsendall}"

calcres "${totsubrmqtt}" "${totwatch}"  "rabbitmqtt (totsubrmqtt)(${totsubrmqtt}) should have the same number of items as ${LGPFX}watch  (${totwatch})"
calcres "${totsubu}" "${totsent}"    "${LGPFX}subscribe u_sftp_f60 (${totsubu}) should have the same number of items as ${LGPFX}sender (${totsent})"
calcres "${totsubcp}" "${totsent}"    "${LGPFX}subscribe cp_f61\t (${totsubcp}) should have the same number of items as ${LGPFX}sender (${totsent})"
echo "                 | poll       routing |"
t7=$((${totsendall}-${totsendremoved}))
calcres "${totpoll1}" "${t7}"         "tot ${LGPFX}poll 1 f62\t (${totpoll1}) should as many as were sent (minus removes) ${LGPFX}sender\t (${t7})"
calcres "${totsubq}" "${totpoll1}"  "${LGPFX}subscribe q_f71\t (${totsubq}) should have the same number of items as ${LGPFX}poll test1_f62 (${totpoll1})"
echo "                 | flow_post  routing |"
calcres "${totpost1}"   "${t5}"         "${LGPFX}post test2_f61\t (${totpost1}) should have half the same number of items of ${LGPFX}sender \t (${totsent})"
calcres "${totsubftp}" "${totpost1}"   "${LGPFX}subscribe ftp_f70\t (${totsubftp}) should have the same number of items as ${LGPFX}post test2_f61 (${totpost1})"
calcres "${totpost1}" "${totshimpost1}" "${LGPFX}post test2_f61\t (${totpost1}) should have about the same number of items as shim_f63\t (${totshimpost1})"

echo "                 | py infos   routing |"
calcres ${totpropagated} ${t6} "${LGPFX}shovel  pclean_f90\t (${totpropagated}) should have twice the number of watched files\t (${totfileamqp})"
zerowanted "${missed_dispositions}" "${maxshovel}" "messages received that we don't know what happened."
# check removed because of issue #294
#calcres ${totshortened} ${totfileamqp} \
#   "count of truncated headers (${totshortened}) and subscribed messages (${totmsgamqp}) should have about the same number of items"

# these almost never are the same, and it's a problem with the post test. so failures here almost always false positives.
#calcres ${totpost1} ${totsubu} "post test2_f61 ${totpost1} and subscribe u_sftp_f60 ${totsubu} run together. Should be about the same."

# because of accept/reject filters (varying amounts of crap being rejected), these numbers are never similar, so these tests are wrong.
# tallyres ${totcpelle04r} ${totcpelle04p} "pump pelle_dd1_f04 (c shovel) should publish (${totcpelle04p}) as many messages as are received (${totcpelle04r})"
# tallyres ${totcpelle05r} ${totcpelle05p} "pump pelle_dd2_f05 (c shovel) should publish (${totcpelle05p}) as many messages as are received (${totcpelle05r})"

if [[ "$C_ALSO" || -d "$SARRAC_LIB" ]]; then

echo "                 | C          routing |"
  calcres  ${totcpelle04r} ${totcpelle05r} "cpump both pelles (c shovel) should receive about the same number of messages (${totcpelle05r}) (${totcpelle04r})"

  totc04recnrej=$(( ${totcpelle04r} - ${totcpelle04rej} )) 
  calcres  ${totc04recnrej} ${totcpelle04p} "cpump pelle 04 (received - rejected) = published (${totcpelle04r} - ${totcpelle04rej}) = ${totc04recnrej} vs. ${totcpelle04p} "

  totc05recnrej=$(( ${totcpelle05r} - ${totcpelle05rej} )) 
  calcres  ${totc05recnrej} ${totcpelle05p} "cpump pelle 05 (received - rejected) = published (${totcpelle05r} - ${totcpelle05rej}) = ${totc05recnrej} vs. ${totcpelle05p} "

  totcvan=$(( ${totcvan14p} + ${totcvan15p} ))
  calcres  ${totcvan} ${totcdnld} "cdnld_f21 subscribe downloaded ($totcdnld) the same number of files that was published by both van_14 and van_15 ($totcvan)"
  calcres ${totcclean} ${totcvan} "${LGPFX}subscribe cclean_f91\t (${totcclean}) should have deleted as many files as went through van\t (${totcvan})"
  t4=$(( ${totcclean} + ${totcvan} ))
  calcres ${totcveille} ${t4} "veille_f34 should post as many files ($totcveille} as wetn through van (${totcvan}) and clean  ($totcclean))"
  t5=$(( $totcveille / 2 ))
  calcres  ${t5} ${totcdnld} "veille_f34 should post twice as many files (${totcveille}) as subscribe cdnld_f21 downloaded (${totcdnld})"
  calcres  ${t5} ${totcfile} "veille_f34 should post twice as many files ($totcveille) as subscribe cfile_f44 downloaded ($totcfile)"

fi

zerowanted  "${messages_unacked}" "${maxshovel}" "there should be no unacknowledged messages left, but there are ${messages_unacked}"
zerowanted  "${messages_ready}" "${maxshovel}" "there should be no messages ready to be consumed but there are ${messages_ready}"

tallyres ${tno} ${passedno} "Overall ${passedno} of ${tno} passed (sample size: $totsarra) !"
results=$?

if (("${missed_dispositions}">0)); then
   # PAS missed_dispositions means definite Sarra bug, very serious.
   echo "Please review $missedreport"
   results=1
fi
echo

exit ${results}
