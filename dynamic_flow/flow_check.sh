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

echo
echo "                 | dd.weather routing | announcing sample data, sarra downloading to ~/sarra_devdocroot"
echo

# following test disabled.
# This is not necessarily true... two shovels with same subscriptions can have quite different numbers of items just because
# of timing around start and stop.
#calcres "${totshovel1}" "${totshovel2}" "${LGPFX}shovel (totshovel1)\t (${totshovel1}) t_dd1 should have the same number of items as t_dd2\t (${totshovel2})"
calcres "${totwinnow}"  "${tot2shov}"   "${LGPFX}winnow (totwinnow)\t (${totwinnow}) should have the same of the number of items of shovels\t (${tot2shov})"
calcres "${totsarp}"   "${totwinpost}" "${LGPFX}sarra (totsarp)\t (${totsarp}) should have the same number of items as winnows'post\t (${totwinpost})"
# since v2.20.04b3... the time comparison is working properly, and subscribe is rejecting unmodified files.
# so this test now... correctly... fails.  commenting out for now.

echo
echo "                 | 1st copy routing | subscribe/amqp_f30 copy to downloaded_by_sub_amqp "
echo
calcres ${totfileamqp}   ${totsarp}    "${LGPFX}subscribe (totfileamqp)\t ${totfileamqp}) should have the same number of items as sarra\t\t (${totsarp})"

#if [ "${V2_SKIP_KNOWN_BAD}" ]; then
    echo
    echo "                 | clean      routing | looking at files in downloaded_by_sub_amqp, creating linked/moved files from there"
    echo

    onethird=$(( ${totfileamqp}/3 ))
    echo "totfileamqp is: +${totfileamqp}+ ... one third is : +${onethird}+"

    calcres "${totcleanslinked}" "${onethird}" "${LGPFX}shovel_pclean_f90 slinks ${totcleanslinked} should be 1/3 of files received ${totfileamqp}"
    calcres "${totcleanhlinked}" "${onethird}" "${LGPFX}shovel_pclean_f90 hlinks  ${totcleanhlinked} should be 1/3 of files received ${totfileamqp}"
    calcres "${totcleanmoved}" "${onethird}" "${LGPFX}shovel_pclean_f90 moved  ${totcleanmoved} should be 1/3 of files received ${totfileamqp}"

    #zerowanted "${totcleanmissed}" "${totfileamqp}" "${LGPFX}shovel_pclean_f90 missed propagations (not in folder errors), "
    if [[ ${totcleanmissed} -gt 0 ]]; then
         echo
         echo "notice: ${totcleanmissed} shovel_pclean_f90 propagations had to be retried. something very slow"
         echo
    fi
         

    expectedcleanpost=$(( ${totfileamqp}+${totcleanslinked}+${totcleanslinked}+${totcleanmoved} ))

    calcres "${totcleanposted}" "${expectedcleanpost}" "${LGPFX}shovel_pclean_f90 posted ${totcleanposted} should equal files received ${expectedcleanpost}"

    t11=$((4*${totcleanhlinked}))
    calcres "${totclean2unlinkhlinked}" "${t11}" "${LGPFX}shovel_pclean_f92 unlink hlinked ${totclean2unlinkhlinked} should be 4 times the files hlinked by pclean_f90 ${totcleanhlinked}"
    t12=$((4*${totcleanmoved}))
    calcres "${totclean2unlinkmoved}" "${t12}" "${LGPFX}shovel_pclean_f92 moved moved ${totclean2unlinkmoved} should be 4 times the files moved by pclean_f90 ${totcleanmoved}"
    t13=$((4*${totcleanslinked}))
    calcres "${totclean2unlinkslinked}" "${t13}" "${LGPFX}shovel_pclean_f92 unlink slinked ${totclean2unlinkslinked} should be 4 times the files slinked by pclean_f90 ${totcleanslinked}"
    
    t14=$((4*${totcleanposted}))
    calcres "${totclean2unlinked}" "${t14}" "${LGPFX}shovel_pclean_f92 unlink ${totclean2unlinked} should be 4 times the files posted by pclean_f90 ${totcleanposted}"
    printf "\n\tclean_f92 unlink breakdown: normal: %d moved: %d hlinks: %d slinks: %d\n" "${totclean2unlinknormal}" "${totclean2unlinkmoved}" "${totclean2unlinkhlinked}" "${totclean2slinked}"

#fi

echo
echo "                 | watch      routing | watching files that arrive in downloaded_by_sub_amqp"
echo

if [ "${V2_SKIP_KNOWN_BAD}" ]; then
   puf=9 # pclean_unlink_factor (how many files are created and unlinked per file downloaded.)
   t8=$(( ${totfileamqp}*${puf} ))
   calcres "${totremoved}"    "${t8}" "${LGPFX}shovel pclean_f92\t (${totremoved}) should have removed ${puf} times the number of files downloaded\t (${totfileamqp})"
fi
calcres "${totwatch}"   "${t4}"         "${LGPFX}watch\t\t (${totwatch}) should be 4 times subscribe amqp_f30\t\t  (${totfileamqp})"
calcres "${totfileamqp}"   "${totwatchnormal}"         "amqp_f30 subscription (totfileamqp)\t\t (${totfileamqp}) should match totwatchnormal\t  (${totwatchnormal})"
calcres "${t6}" "${totwatchremoved}" "watch rm's (totwatchremove) (${totwatchremoved}) should be t6=2*totfileamqp (${t6})"

printf "\n\twatch breakdown: totwatchhlinked: %4d totwatchslinked: %4d totwatchmoved: %4d\n" "${totwatchhlinked}" "${totwatchslinked}" "${totwatchmoved}"

printf "\t\t\t totwatchnormal: %4d  totwatchdir: %4d totwatchall: %4d\n"  "${totwatchnormal}" "${totwatchdir}" "${totwatchall}"
printf "\t\t\t totwatchremoved: %4d  totwatchrmfiles: %4d  totwatchrmdirs: %4d \n"  "${totwatchremoved}" "${totwatchrmfiles}" "${totwatchrmdirs}" 


calcres "${totwatchhlinked}" "${totwatchslinked}" "totwatchhlinked\t (${totwatchhlinked}) should match symlinkes (totwatchslinked) \t  (${totwatchslinked})"
#calcres "${totwatchmoved}" "${totwatchhlinked}" "watchmoved (${totwatchmoved}) should be same as number watchhlinked (${totwatchhlinked})"

# this test is not accurate... replaced by t10 one.
#t9=$(( ${totwatchnormal}*2 ))
#calcres "${totwatchremoved}" "${t9}" "watchremoved \t\t (${totwatchremoved}) should 2x files downloaded watchslinked \t  (${t9})"

printf "\ntotwatchremoved should == totwatchnormal+totwatchslinked+totwatchhlinked+totwatchdirs\n"
printf "so all the normal files go by (totwatchnormal), and then for each one, pclean_f90 either hlinks, slinks or renames it.\n"
printf "then they should all be removed by pclean_f92. (moves generate a remove as well)\n\n"
t10=$(( ${totwatchnormal}+${totwatchhlinked}+${totwatchslinked} ))
calcres "${totwatchremoved}" "${t10}" "watchremoved \t\t (${totwatchremoved}) should match the above\t  (${t10})"


#following is just wrong... 
#calcres "${totwatchall}" "${totwatch}" "watchremoved (${totwatchall}) should be same as number totwatch (${totwatch})"

echo
echo "                 | sftp-send routing | sender/tsource2send sends to /sent_by_tsource2send directory"
echo
calcres "${totsent}"    "${totwatch}"   "${LGPFX}sender (totsent)\t (${totsent}) should have the same number of items as ${LGPFX}watch  (${totwatch})"

printf "\n\tsend breakdown: totsendhlinked: %4d totsendslinked: %4d totsendmoved: %4d\n" "${totsendhlinked}" "${totsendslinked}" "${totsendmoved}"
printf "\t\t\t totsendmkdir: %4d  totsendremoved: %4d  totsendnormal: %4d   totsendall: %4d\n" "${totsendmkdir}"  "${totsendremoved}" "${totsendnormal}" "${totsendall}"

calcres "${totsubrmqtt}" "${totwatch}"  "rabbitmqtt (totsubrmqtt)(${totsubrmqtt}) should have the same number of items as ${LGPFX}watch  (${totwatch})"
calcres "${totsubu}" "${totsent}"    "${LGPFX}subscribe u_sftp_f60 (${totsubu}) should have the same number of items as ${LGPFX}sender (${totsent})"
calcres "${totsubcp}" "${totsent}"    "${LGPFX}subscribe cp_f61\t (${totsubcp}) should have the same number of items as ${LGPFX}sender (${totsent})"
echo
echo "                 | poll       routing | polling the sent_by_tsource2send/ directory with sftp "
echo
t7=$((${totsendall}-${totsendremoved}))
calcres "${totpoll1}" "${t7}"         "tot ${LGPFX}poll 1 f62\t (${totpoll1}) should as many as were sent (minus removes) ${LGPFX}sender\t (${t7})"

if [ "${sarra_py_version:0:1}" == "3" ]; then

    calcres "${totsubq}" "${totpoll1}"  "${LGPFX}subscribe q_f71\t (${totsubq}) should have the same number of items as ${LGPFX}poll test1_f62 (${totpoll1})"
else
    t8=$((${totpoll1}*2))
    calcres "${totsubq}" "${t8}"  "${LGPFX}subscribe q_f71\t (${totsubq}) should have double the number of items as ${LGPFX}poll test1_f62 (${totpoll1})"

fi

echo
echo "                 | flow_post  routing | shim library and ls manual posting of contents of /sent_by_tsource2send directory"
echo
calcres "${totpost1}"   "${t5}"         "${LGPFX}post test2_f61\t (${totpost1}) should have half the same number of items of ${LGPFX}sender \t (${totsent})"
calcres "${totsubftp}" "${totpost1}"   "${LGPFX}subscribe ftp_f70\t (${totsubftp}) should have the same number of items as ${LGPFX}post test2_f61 (${totpost1})"
calcres "${totpost1}" "${totshimpost1}" "${LGPFX}post test2_f61\t (${totpost1}) should have about the same number of items as shim_f63\t (${totshimpost1})"

echo
echo "                 | py infos   routing |"
echo
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

echo
echo "                 | C          routing |"
echo

  calcres  ${totcpelle04r} ${totcpelle05r} "cpump both pelles (c shovel) should receive about the same number of messages (${totcpelle05r}) (${totcpelle04r})"

  totc04recnrej=$(( ${totcpelle04r} - ${totcpelle04rej} )) 
  calcres  ${totc04recnrej} ${totcpelle04p} "cpump pelle 04 (received - rejected) = published (${totcpelle04r} - ${totcpelle04rej}) = ${totc04recnrej} vs. ${totcpelle04p} "

  totc05recnrej=$(( ${totcpelle05r} - ${totcpelle05rej} )) 
  calcres  ${totc05recnrej} ${totcpelle05p} "cpump pelle 05 (received - rejected) = published (${totcpelle05r} - ${totcpelle05rej}) = ${totc05recnrej} vs. ${totcpelle05p} "

  totcvan=$(( ${totcvan14p} + ${totcvan15p} ))
  calcres  ${totcvan} ${totcdnld} "cdnld_f21 subscribe downloaded ($totcdnld) the same number of files that was published by both van_14 and van_15 ($totcvan)"
if [ "${sarra_py_version:0:1}" == "3" ]; then
  calcres ${totcclean} ${totcvan} "${LGPFX}subscribe cclean_f91\t (${totcclean}) should have deleted as many files as went through van\t (${totcvan})"
else
  calcres ${totcclean_skipped} ${totcvan} "${LGPFX}subscribe cclean_f91\t (${totcclean_skipped}) should have skipped as many files as went through van\t (${totcvan})"
fi
  t4=$(( ${totcclean} + ${totcvan} ))
  calcres ${totcveillefile} ${t4} "veille_f34 should post as many files ($totcveillefile} as went through van (${totcvan}) and clean  ($totcclean))"

  # once the v03 formats changed with fileOp and identity, the v2 sarrac isn't uptodate, will give false failures.
  if [ ! "${V2_SKIP_KNOWN_BAD}" ]; then
    t5=$(( $totcveillefile / 2 ))
    calcres  ${t5} ${totcdnld} "veille_f34 should post twice as many files (${totcveillefile}) as subscribe cdnld_f21 downloaded (${totcdnld})"
    calcres  ${t5} ${totcfile} "veille_f34 should post twice as many files ($totcveillefile) as subscribe cfile_f44 downloaded ($totcfile)"
  fi

fi

zerowanted  "${messages_unacked}" "${maxshovel}" "broker unacknowledged messages"
zerowanted  "${messages_ready}" "${maxshovel}" "broker messages ready to be consumed (queued but not consumed)"

tallyres ${tno} ${passedno} "Overall ${passedno} of ${tno} passed (sample size: $totsarra) !"
results=$?

if (("${missed_dispositions}">0)); then
   # PAS missed_dispositions means definite Sarra bug, very serious.
   echo "Please review $missedreport"
   results=1
fi
echo

exit ${results}
