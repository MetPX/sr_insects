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
checktree ${testdocroot}/downloaded_by_sub_amqp
checktree ${testdocroot}/downloaded_by_sub_cp
checktree ${testdocroot}/downloaded_by_sub_rabbitmqtt
checktree ${testdocroot}/downloaded_by_sub_u
checktree ${testdocroot}/posted_by_shim
checktree ${testdocroot}/recd_by_srpoll_test1
checktree ${testdocroot}/sent_by_tsource2send
# Not used in flakey? RS
#checktree ${testdocroot}/mirror/linked_by_shim
checktree ${testdocroot}/cfile
checktree ${testdocroot}/cfr


if [[ -z "$skip_summaries" ]]; then
    # PAS performance summaries
    printf "\nDownload Performance Summaries:\tLOGDIR=$LOGDIR\n"
    summarize_performance ${LGPFX}shovel msg_total: rabbitmqtt_f22
    summarize_performance ${LGPFX}subscribe file_total: cdnld_f21 amqp_f30 cfile_f44 u_sftp_f60 ftp_f70 q_f71

    echo
    # MG shows retries
    echo

    if [[ ! "$SARRA_LIB" ]]; then
       echo NB retries for ${LGPFX}subscribe amqp_f30 `grep Retrying "$LOGDIR"/${LGPFX}subscribe_amqp_f30*.log | wc -l`
       echo NB retries for ${LGPFX}sender    `grep Retrying "$LOGDIR"/${LGPFX}sender*.log | wc -l`
    else
       echo NB retries for "$SARRA_LIB"/${LGPFX}subscribe.py amqp_f30 `grep Retrying "$LOGDIR"/${LGPFX}subscribe_amqp_f30*.log | wc -l`
       echo NB retries for "$SARRA_LIB"/${LGPFX}sender.py    `grep Retrying "$LOGDIR"/${LGPFX}sender*.log | wc -l`
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

echo "                 | content of subdirs of ${testdocroot} |"
comparetree downloaded_by_sub_amqp downloaded_by_sub_cp
comparetree downloaded_by_sub_cp downloaded_by_sub_rabbitmqtt
comparetree downloaded_by_sub_rabbitmqtt downloaded_by_sub_u
comparetree downloaded_by_sub_u posted_by_shim
# RS not used?
#comparetree downloaded_by_sub_amqp linked_by_shim
comparetree posted_by_shim sent_by_tsource2send
comparetree downloaded_by_sub_amqp cfile
comparetree cfile cfr

tot2shov=$(( ${totshovel1} + ${totshovel2} ))
t4=$(( ${totfileamqp}*4 ))

echo "                 | dd.weather routing |"
expected_xattr_cnt=2242
src_xattr_cnt="`find ${SAMPLEDATA} -type f | xargs xattr -l|wc -l`"
calcres ${src_xattr_cnt} ${expected_xattr_cnt} "expected ${expected_xattr_cnt} number of extended attributes in source tree ${src_xattr_cnt}"





calcres ${staticfilecount} ${totshovel2} "${LGPFX}post\t count of posted files (${totshovel2}) should be same those in the static data directory\t (${staticfilecount})"
calcres "${rejectfilecount}" "${totshovel2rej}" "${LGPFX}post\t count of rejected files (${totshovel2rej}) should be same those in the static data directory\t (${rejectfilecount})"

calcres ${totshovel1} ${totshovel2} "${LGPFX}post\t (${totshovel1}) t_dd1 should have the same number of items as t_dd2\t (${totshovel2})"
calcres ${totsarp}    ${totshovel1} "${LGPFX}sarra\t (${totsarp}) should have the same number of items as one post\t (${totshovel1})"
calcres ${totwinnowed}    ${totshovel1} "${LGPFX}sarra\t (${totwinnowed}) should winnow the same number of items as one post\t (${totshovel1})"
calcres ${totfileamqp}   ${totsarp}    "${LGPFX}subscribe amqp_f30\t (${totfileamqp}) should have the same number of items as sarra\t\t (${totsarp})"
echo "                 | watch      routing |"
calcres ${totwatch}   ${totfileamqp}         "${LGPFX}watch\t\t (${totwatch}) should be the same as subscribe amqp_f30\t\t  (${totfileamqp})"
calcres ${totsent}    ${totwatch}   "${LGPFX}sender\t\t (${totsent}) should have the same number of items as ${LGPFX}watch  (${totwatch})"
calcres ${totsubrmqtt} ${totwatch}  "rabbitmqtt\t\t (${totsubrmqtt}) should have the same number of items as ${LGPFX}watch  (${totwatch})"
calcres ${totsubu}    ${totsent}    "${LGPFX}subscribe u_sftp_f60 (${totsubu}) should have the same number of items as ${LGPFX}sender (${totsent})"
calcres ${totsubcp}   ${totsent}    "${LGPFX}subscribe cp_f61\t (${totsubcp}) should have the same number of items as ${LGPFX}sender (${totsent})"
echo "                 | poll       routing |"
calcres ${totpoll1}   ${totsent}         "${LGPFX}poll sftp_f62\t (${totpoll1}) should have the same number of items of ${LGPFX}sender\t (${totsent})"
if [ "${totpoll_mirrored}" ]; then
    calcres "${totpoll1}" "${totpoll_mirrored}" "${LGPFX}poll sftp_f63\t (${totpoll_mirrored}) should see the same number of items as ${LGPFX}poll sftp_f62 posted\t (${totsent})"
fi

calcres ${totsubq}    ${totpoll1}   "${LGPFX}subscribe q_f71\t (${totsubq}) should have the same number of items as ${LGPFX}poll sftp_f62 (${totpoll1})"
echo "                 | flow_post  routing |"
calcres ${totpost1}   ${totsent}         "${LGPFX}post test2_f61\t (${totpost1}) should have the same number of items of ${LGPFX}sender \t (${totsent})"
calcres ${totsubftp}  ${totpost1}   "${LGPFX}subscribe ftp_f70\t (${totsubftp}) should have the same number of items as ${LGPFX}post test2_f61 (${totpost1})"
calcres ${totpost1} ${totshimpost1} "${LGPFX}post test2_f61\t (${totpost1}) should have about the same number of items as shim_f63\t (${totshimpost1})"

echo "                 | py infos   routing |"
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
  calcres  ${totcpelle04_rl} ${totcpelle05_rl} "cpost both pelles should see same amount of post_rate_limit messages (${totcpelle04_rl}) (${totcpelle05_rl})"
  t14=$(( ${totcpelle04_rl}*5 ))
  calcres  ${totcpelle04p} ${t14} "cpost pelle04 should post 5 times the number of post_rate_limit messages (${totcpelle04p}) (${totcpelle04_rl})"

  totcvan=$(( ${totcvan14p} + ${totcvan15p} ))
  calcres  ${totcvan} ${totcdnld} "cdnld_f21 subscribe downloaded ($totcdnld) the same number of files that was published by both van_14 and van_15 ($totcvan)"
  t5=$(( $totcveille / 2 ))
  calcres  ${totcveille} ${totcdnld} "veille_f34 should post as many files ($totcveille) as subscribe cdnld_f21 downloaded ($totcdnld)"
  calcres  ${totcveille} ${totcfile} "veille_f34 should post as many files ($totcveille) as subscribe cfile_f44 downloaded ($totcfile)"

fi

tallyres ${tno} ${passedno} "Overall ${passedno} of ${tno} passed (sample size: $staticfilecount) !"
results=$?

if (("${missed_dispositions}">0)); then
   # PAS missed_dispositions means definite Sarra bug, very serious.
   echo "Please review $missedreport"
   results=1
fi
echo

exit ${results}
