#!/bin/bash

. ../flow_utils.sh

C_ALSO="`which sr_cpost`"
# The directory we run the flow test scripts in...
tstdir="`pwd`"
httpdocroot=`cat $tstdir/.httpdocroot`

function countthem {
   if [ ! "${1}" ]; then
      tot=0
   else
      tot="${1}"
   fi
}

function chkargs {

   if [[ ! "${1}" || ! "${2}" ]]; then
      printf "test %2d FAILURE: blank results! ${3}\n" ${tno}
      return 2
   fi
   if [[ "${1}" -eq 0 ]]; then
      printf "test %2d FAILURE: no successful results! ${3}\n" ${tno}
      return 2
   fi

   if [[ "${2}" -eq 0 ]]; then
      printf "test %2d FAILURE: no successful results, 2nd item! ${3}\n" ${tno}
      return 2
   fi

   return 0
}

function calcres {
   #
   # calcres - Calculate test result.
   # 
   # logic:
   # increment test number (tno)
   # compare first and second totals, and report agreement if within 10% of one another.
   # emit description based on agreement.  Arguments:
   # 1 - first total
   # 2 - second total 
   # 3 - test description string.
   # 4 - will retry flag.
   #
   
   tno=$((${tno}+1))

   chkargs "${1}" "${2}" "${3}"
   if [ $? -ne 0 ]; then
      return $?
   fi

   res=0

   mean=$(( (${1} + ${2}) / 2 ))
   maxerr=$(( $mean / 10 ))

   min=$(( $mean - $maxerr ))
   max=$(( $mean + $maxerr ))

   if [ $1 -lt $min -o $2 -lt $min -o $1 -gt $max -o $1 -gt $max ]; then
	   printf "test %2d FAILURE: ${3}\n" ${tno}
      if [ "$4" ]; then
         tno=$((${tno}-1))
      fi    
      return 1
   else
      printf "test %2d success: ${3}\n" ${tno}
      passedno=$((${passedno}+1))
      return 0
   fi

}

function tallyres {
   # tallyres - All the results must be good.  99/100 is bad!
   # 
   # logic:
   # increment test number (tno)
   # compare first and second totals, and report agreement of one another.
   # emit description based on agreement.  Arguments:
   # 1 - value obtained 
   # 2 - value expected
   # 3 - test description string.

   tno=$((${tno}+1))

   if [ ${1} -ne ${2} -o ${2} -eq 0 ]; then
      printf "test %2d FAILURE: ${3}\n" ${tno}
      if [ "$4" ]; then
         tno=$((${tno}-1))
      fi    
      return 1
   else
      printf "test %2d success: ${3}\n" ${tno}
      passedno=$((${passedno}+1))
      return 0
   fi

}

function zerowanted {
   # zerowanted - this value must be zero... checking for bad things.
   # 
   # logic:
   # increment test number (tno)
   # compare first and second totals, and report agreement if within 10% of one another.
   # emit description based on agreement.  Arguments:
   # 1 - value obtained 
   # 2 - samplesize
   # 3 - test description string.

   tno=$((${tno}+1))

   if [ "${2}" -eq 0 ]; then
      printf "test %2d FAILURE: no data! ${3}\n" ${tno}
      return
   fi

   if [ "${1}" -gt 0 ]; then
      printf "test %2d FAILURE: ${1} ${3}\n" ${tno}
   else
      printf "test %2d success: ${1} ${3}\n" ${tno}
      passedno=$((${passedno}+1))
   fi
}

function sumlogs {

  pat="$1"
  shift
  tot=0
  for l in $*; do
     if [ "${sarra_py_version%%.*}" == '3' ]; then
         to_add="`grep -a "$pat" $l | tail -1 | awk ' { if ( $6 == "msg_total:" ) print $7; else print $5; }; '`"
     else
         to_add="`grep -a "\[INFO\] $pat" $l | tail -1 | awk ' { print $5; }; '`"
     fi
     if [ "$to_add" ]; then
        tot=$((${tot}+${to_add}))
     fi
  done
}

function sumlogshistory {
  p="$1"
  shift
  if [[ $(ls $* 2>/dev/null) ]]; then
      reverse_date_logs=`ls $* | sort -n -r`

      for l in $reverse_date_logs; do
         if [[ ${tot} = 0 ]]; then
             sumlogs $p $l
         fi
      done
  fi
}

function countall {

  sumlogs msg_total $LOGDIR/sr_report_tsarra_f20_*.log
  totsarra="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
       countthem "`grep -a 'getNewMessage new msg' "$LOGDIR"/sr_report_twinnow00_f10_01.log | wc -l`"
  else
       sumlogs msg_total $LOGDIR/sr_report_twinnow00_f10_*.log
  fi
  totwinnow00="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
       countthem "`grep -a 'getNewMessage new msg' "$LOGDIR"/sr_report_twinnow01_f10_01.log | wc -l`"
  else
       sumlogs msg_total $LOGDIR/sr_report_twinnow01_f10_*.log
  fi
  totwinnow01="${tot}"

  totwinnow=$(( ${totwinnow00} + ${totwinnow01} ))

  if [ "${sarra_py_version:0:1}" == "3" ]; then
       countthem "`grep -a 'putNewMessage published' "$LOGDIR"/sr_shovel_t_dd1_f00_*.log | wc -l`"
  else
       sumlogs msg_total $LOGDIR/sr_shovel_t_dd1_f00_*.log
  fi
  totshovel1="${tot}"


  if [ "${sarra_py_version:0:1}" == "3" ]; then
       countthem "`grep -a 'putNewMessage published' "$LOGDIR"/sr_shovel_t_dd2_f00_*.log | wc -l`"
  else
       sumlogs msg_total $LOGDIR/sr_shovel_t_dd2_f00_*.log
  fi
  totshovel2="${tot}"

  countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/sr_winnow*.log | wc -l`"
  totwinpost="${tot}"
  countthem "`grep -a ' published ' "$LOGDIR"/sr_winnow*.log | wc -l`"
  totwinpost=$(( (${totwinpost} + ${tot}) ))

  countthem "`grep -a truncating "$LOGDIR"/sr_sarra_download_f20_*.log | grep -v DEBUG | wc -l`"
  totshortened="${tot}"


  if [ "${sarra_py_version:0:1}" == "3" ]; then
      countthem "`grep -a 'post message:' "$LOGDIR"/sr_watch_f40_*.log | wc -l`"
  else
      countthem "`grep -a '\[INFO\] post_log' "$LOGDIR"/sr_watch_f40_*.log | wc -l`"
  fi
  totwatch=${tot}



  sumlogs msg_total $LOGDIR/sr_subscribe_amqp_f30_*.log
  totmsgamqp="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
      countthem "`grep -a 'do_download downloaded ok' "$LOGDIR"/sr_subscribe_amqp_f30_*.log | wc -l`"
  else
      countthem "`grep -a '\[INFO\] file_log downloaded to:' "$LOGDIR"/sr_subscribe_amqp_f30_*.log | wc -l`"
  fi
  totfileamqp="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
      countthem "`grep -a 'putNewMessage published' "$LOGDIR"/sr_sender_tsource2send_f50_*.log | wc -l`"
  else
      countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/sr_sender_tsource2send_f50_*.log | wc -l`"
  fi
  totsent="${tot}"

  no_hardlink_events='downloaded to:|symlinked to|removed'
  all_events="hardlink|$no_hardlink_events"
  if [ "${sarra_py_version:0:1}" == "3" ]; then
      all_events="do_download\ downloaded\ ok|write_inline_file\ data\ inlined\ with\ message"
      countthem "`grep -aE "$all_events" "$LOGDIR"/sr_subscribe_rabbitmqtt_f31_*.log | grep -v DEBUG | wc -l`"
  else
      no_hardlink_events='downloaded to:|symlinked to|removed'
      all_events="hardlink|$no_hardlink_events"
      countthem "`grep -aE "$all_events" "$LOGDIR"/sr_subscribe_rabbitmqtt_f31_*.log | grep -v DEBUG | wc -l`"
  fi
  totsubrmqtt="${tot}"

  countthem "`grep -aE "$all_events" "$LOGDIR"/sr_subscribe_u_sftp_f60_*.log | grep -v DEBUG | wc -l`"
  totsubu="${tot}"
  countthem "`grep -aE "$all_events" "$LOGDIR"/sr_subscribe_cp_f61_*.log | grep -v DEBUG | wc -l`"
  totsubcp="${tot}"

  #countthem "`grep -aE "$no_hardlink_events" "$LOGDIR"/sr_subscribe_ftp_f70_*.log | grep -v DEBUG | wc -l`"
  if [ "${sarra_py_version:0:1}" == "3" ]; then
      all_events="do_download downloaded ok"
      countthem "`grep -aE "$all_events" "$LOGDIR"/sr_subscribe_ftp_f70_*.log | grep -v DEBUG | wc -l`"
  else
      countthem "`grep -aE "$no_hardlink_events" "$LOGDIR"/sr_subscribe_ftp_f70_*.log | grep -v DEBUG | wc -l`"
  fi
  totsubftp="${tot}"
  countthem "`grep -aE "$all_events" "$LOGDIR"/sr_subscribe_q_f71_*.log | grep -v DEBUG | wc -l`"
  totsubq="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
       countthem "`grep -a 'putNewMessage published' "$LOGDIR"/sr_poll_f62_*.log | wc -l`"
  else
       countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/sr_poll_f62_*.log | wc -l`"
  fi
  totpoll1="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
       countthem "`grep -a 'putNewMessage published' $srposterlog | grep -v shim | wc -l`"
  else
       countthem "`grep -a '\[INFO\] post_log notice' $srposterlog | grep -v shim | wc -l`"
  fi
  totpost1="${tot}"

  countthem "`grep -a '\[INFO\] published:' $srposterlog | grep shim | wc -l`"
  totshimpost1="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
      countthem "`grep -a 'putNewMessage published' "$LOGDIR"/sr_sarra_download_f20_*.log | wc -l`"
  else
      countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/sr_sarra_download_f20_*.log | wc -l`"
  fi
  totsarp="${tot}"

  if [[ ! "$C_ALSO" && ! -d "$SARRAC_LIB" ]]; then
     return
  fi

  countthem "`grep -a '\[INFO\] received:' $LOGDIR/sr_cpump_pelle_dd1_f04_*.log | wc -l`"
  totcpelle04r="${tot}"

  countthem "`grep -a '\[INFO\] rejecting ' $LOGDIR/sr_cpump_pelle_dd1_f04_*.log | wc -l`"
  totcpelle04rej="${tot}"

  countthem "`grep -a '\[INFO\] published:' $LOGDIR/sr_cpump_pelle_dd1_f04_*.log | wc -l`"
  totcpelle04p="${tot}"

  countthem "`grep -a '\[INFO\] received:' $LOGDIR/sr_cpump_pelle_dd2_f05_*.log | wc -l`"
  totcpelle05r="${tot}"

  countthem "`grep -a '\[INFO\] rejecting ' $LOGDIR/sr_cpump_pelle_dd2_f05_*.log | wc -l`"
  totcpelle05rej="${tot}"

  countthem "`grep -a '\[INFO\] published:' $LOGDIR/sr_cpump_pelle_dd2_f05_*.log | wc -l`"
  totcpelle05p="${tot}"

  countthem "`grep -a '\[INFO\] published:' $LOGDIR/sr_cpump_xvan_f14_*.log | wc -l`"
  totcvan14p="${tot}"

  countthem "`grep -a '\[INFO\] published:' $LOGDIR/sr_cpump_xvan_f15_*.log | wc -l`"
  totcvan15p="${tot}"

  countthem "`grep -a '\[INFO\] published:' $LOGDIR/sr_cpost_veille_f34_*.log | wc -l`"
  totcveille="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
      countthem "`grep -a 'do_download downloaded ok' $LOGDIR/sr_subscribe_cdnld_f21_*.log | wc -l`"
  else
      countthem "`grep -a '\[INFO\] file_log downloaded ' $LOGDIR/sr_subscribe_cdnld_f21_*.log | wc -l`"
  fi
  totcdnld="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
      countthem "`grep -a 'do_download downloaded ok' $LOGDIR/sr_subscribe_cfile_f44_*.log | wc -l`"
  else
      countthem "`grep -a '\[INFO\] file_log downloaded ' $LOGDIR/sr_subscribe_cfile_f44_*.log | wc -l`"
  fi
  totcfile="${tot}"

  if [[ $(ls "$LOGDIR"/sr_shovel_pclean_f90*.log 2>/dev/null) ]]; then
      if [ ${sarra_py_version%%.*} == '3' ]; then
          countthem "`grep -a 'published' "$LOGDIR"/sr_shovel_pclean_f90*.log | wc -l`"
      else 
          countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/sr_shovel_pclean_f90*.log | wc -l`"
      fi
      totpropagated="${tot}"
  else
      totpropagated="0"
  fi

  if [[ $(ls "$LOGDIR"/sr_shovel_pclean_f92*.log 2>/dev/null) ]]; then
      if [ ${sarra_py_version%%.*} == '3' ]; then
          countthem "`grep -a 'published' "$LOGDIR"/sr_shovel_pclean_f92*.log | wc -l`"
      else
          countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/sr_shovel_pclean_f92*.log | wc -l`"
      fi
      totremoved="${tot}"
  else
      totremoved="0"
  fi

  # flags when two lines include *msg_log received* (with no other message between them) indicating no user will know what happenned.
  awk 'BEGIN { lr=0; }; /msg_log received/ { lr++; print lr, FILENAME, $0 ; next; }; { lr=0; } '  $LOGDIR/sr_subscribe_*_f??_??.log  | grep -v '^1 ' >$missedreport
  missed_dispositions="`wc -l <$missedreport`"

}

