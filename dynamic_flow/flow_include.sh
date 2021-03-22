#!/bin/bash

. ../flow_utils.sh

C_ALSO="`which sr_cpost`"
# The directory we run the flow test scripts in...
tstdir="`pwd`"
httpdocroot=`cat $tstdir/.httpdocroot`
numre="^[0-9]+$"

function countthem {
   if [ ! "${1}" ]; then
      tot=0
   elif ! [[ "${1}" =~ ${numre} ]]; then
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
         to_add="`grep -a "$pat" $l | tail -1 | awk ' { if ( $6 == "msg_total:" ) print $7; else print $6; }; '`"
     else
         to_add="`grep -a "\[INFO\] $pat" $l | tail -1 | awk ' { print $5; }; '`"
     fi
     if ! [[ "${to_add}" =~ ${numre} ]]; then
        to_add=0
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

  if [ "${sarra_py_version:0:1}" == "3" ]; then
      countthem "`grep -a 'putNewMessage published' "$LOGDIR"/sarra_download_f20*.log | wc -l`"
  else
      countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/${LGPFX}sarra*.log | wc -l`"
  fi
  totsarra="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
       countthem "`grep -a 'putNewMessage published' "$LOGDIR"/winnow_t00_f10_01.log | wc -l`"
  else
       countthem "`grep -a 'Ignored' "$LOGDIR"/sr_winnow_t00_f10_01.log | wc -l`"
  fi
  totwin00ignored="${tot}"


  if [ "${sarra_py_version:0:1}" == "3" ]; then
       countthem "`grep -a 'putNewMessage published' "$LOGDIR"/winnow_t01_f10_01.log | wc -l`"
  else
       countthem "`grep -a 'Ignored' "$LOGDIR"/sr_winnow_t01_f10_01.log | wc -l`"
  fi
  totwin01ignored="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
       countthem "`grep -a 'putNewMessage published' "$LOGDIR"/shovel_t_dd1_f00_*.log | wc -l`"
  else
       sumlogs msg_total $LOGDIR/sr_shovel_t_dd1_f00_*.log
  fi
  totshovel1="${tot}"


  if [ "${sarra_py_version:0:1}" == "3" ]; then
       countthem "`grep -a 'putNewMessage published' "$LOGDIR"/shovel_t_dd2_f00_*.log | wc -l`"
  else
       sumlogs msg_total $LOGDIR/sr_shovel_t_dd2_f00_*.log
  fi
  totshovel2="${tot}"

  countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/${LGPFX}winnow*.log | wc -l`"
  totwin00post="${tot}"
  countthem "`grep -a ' published ' "$LOGDIR"/${LGPFX}winnow*.log | wc -l`"
  totwin01post="${tot}"

  totwinnow01=$((${totwin01post}+${totwin01ignored}))
  totwinnow00=$((${totwin00post}+${totwin00ignored}))
  totwinpost=$((${totwin00post}+${totwin01post}))
  totwinignored=$(( ${totwin00ignored}+${totwin01ignored}))
  totwinnow=$((${totwinnow00}+${totwinnow01}))

  countthem "`grep -a truncating "$LOGDIR"/${LGPFX}sarra_download_f20_*.log | grep -v DEBUG | wc -l`"
  totshortened="${tot}"


  if [ "${sarra_py_version:0:1}" == "3" ]; then
      countthem "`grep -a 'putNewMessage published' "$LOGDIR"/watch_f40_*.log | wc -l`"
      totwatch=${tot}
      countthem "`grep -aE 'putNewMessage published.*\.moved' "$LOGDIR"/${LGPFX}watch_f40_*.log | grep -v "'remove', " | wc -l`"
      totwatchmoved=${tot}
      countthem "`grep -aE 'putNewMessage published.*\.hlink' "$LOGDIR"/${LGPFX}watch_f40_*.log | wc -l`"
      totwatchhlinked=${tot}
      countthem "`grep -aE 'putNewMessage published.*\.slink' "$LOGDIR"/${LGPFX}watch_f40_*.log | wc -l`"
      totwatchslinked=${tot}
      countthem "`grep -aE "putNewMessage published.*'remove'," "$LOGDIR"/${LGPFX}watch_f40_*.log | grep -v newname | wc -l`"
      totwatchremoved=${tot}
      countthem "`grep -aE "putNewMessage published.*" "$LOGDIR"/${LGPFX}watch_f40_*.log | grep -avE 'remove|.slink|.hlink|.moved' | wc -l`"
  else
      countthem "`grep -a '\[INFO\] post_log' "$LOGDIR"/sr_watch_f40_*.log | wc -l`"
      totwatch=${tot}
      countthem "`grep -aE 'post_log.*\.moved' "$LOGDIR"/${LGPFX}watch_f40_*.log | grep -v "'remove', " | wc -l`"
      totwatchmoved=${tot}
      countthem "`grep -aE 'post_log.*\.hlink' "$LOGDIR"/${LGPFX}watch_f40_*.log | wc -l`"
      totwatchhlinked=${tot}
      countthem "`grep -aE 'post_log.*\.slink' "$LOGDIR"/${LGPFX}watch_f40_*.log | wc -l`"
      totwatchslinked=${tot}
      countthem "`grep -aE "post_log.*'remove'," "$LOGDIR"/${LGPFX}watch_f40_*.log | wc -l`"
      totwatchremoved=${tot}
      countthem "`grep -aE "post_log.*" "$LOGDIR"/${LGPFX}watch_f40_*.log | grep -avE 'remove|.slink|.hlink|.moved' | wc -l`"
  fi
  totwatchnormal=${tot}

  totwatchall=$((${totwatchnormal}+${totwatchremoved}+${totwatchslinked}+${totwatchmoved}+${totwatchhlinked}))

  sumlogs msg_total $LOGDIR/${LGPFX}subscribe_amqp_f30_*.log
  totmsgamqp="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
      countthem "`grep -a 'do_download downloaded ok' "$LOGDIR"/subscribe_amqp_f30_*.log | wc -l`"
  else
      countthem "`grep -a '\[INFO\] file_log downloaded to:' "$LOGDIR"/sr_subscribe_amqp_f30_*.log | wc -l`"
  fi
  totfileamqp="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
      countthem "`grep -a 'putNewMessage published' "$LOGDIR"/sender_tsource2send_f50_*.log | wc -l`"
      totsent="${tot}"
      countthem "`grep -aE 'putNewMessage published .*oldname.:' "$LOGDIR"/${LGPFX}sender_tsource2send_f50_*.log | wc -l`"
      totsendmoved=${tot}
      countthem "`grep -aE 'putNewMessage published.*\.hlink' "$LOGDIR"/${LGPFX}sender_tsource2send_f50_*.log | wc -l`"
      totsendhlinked=${tot}
      countthem "`grep -aE 'putNewMessage published.*{.link.:' "$LOGDIR"/${LGPFX}sender_tsource2send_f50_*.log | wc -l`"
      totsendslinked=${tot}
      countthem "`grep -aE "putNewMessage published.*'sum': 'R," "$LOGDIR"/${LGPFX}sender_tsource2send_f50_*.log | grep -v newname | wc -l`"
      totsendremoved=${tot}

      countthem "`grep -a "putNewMessage published" "$LOGDIR"/${LGPFX}sender_tsource2send_f50_*.log | grep -avE 'newname|link|remove|\.moved' | wc -l`"
      totsendnormal=${tot}
  else
      countthem "`grep -aE '\[INFO\] post_log notice.*oldname.:' "$LOGDIR"/sr_sender_tsource2send_f50_*.log | wc -l`"
      totsendmoved=${tot}

      countthem "`grep -aE '\[INFO\] post_log notice.*\.hlink' "$LOGDIR"/sr_sender_tsource2send_f50_*.log | wc -l`"
      totsendhlinked=${tot}

      countthem "`grep -aE '\[INFO\] post_log notice.*\.slink' "$LOGDIR"/sr_sender_tsource2send_f50_*.log | wc -l`"
      totsendslinked=${tot}

      countthem "`grep -aE "'\[INFO\] post_log notice.*'sum': 'R," "$LOGDIR"/sr_sender_tsource2send_f50_*.log | grep -avE 'newname' | wc -l`"
      totsendremoved=${tot}

      countthem "`grep -aE "\[INFO\] post_log notice" "$LOGDIR"/sr_sender_tsource2send_f50_*.log | grep -avE 'newname|link|remove|\.moved' | wc -l`"
      totsendnormal=${tot}

      countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/sr_sender_tsource2send_f50_*.log | wc -l`"
      totsent="${tot}"
  fi
  totsendall=$((${totsendnormal}+${totsendremoved}+${totsendhlinked}+${totsendslinked}+${totsendmoved}))

  no_hardlink_events='downloaded to:|symlinked to|removed'
  all_events="hardlink|$no_hardlink_events"
  if [ "${sarra_py_version:0:1}" == "3" ]; then
      all_events="do_download\ downloaded\ ok|write_inline_file\ data\ inlined\ with\ message|renamed|symlinked to"
      countthem "`grep -aE "$all_events" "$LOGDIR"/${LGPFX}subscribe_rabbitmqtt_f31_*.log | grep -v DEBUG | wc -l`"
  else
      no_hardlink_events='downloaded to:|symlinked to|removed'
      all_events="hardlink|$no_hardlink_events"
      countthem "`grep -aE "$all_events" "$LOGDIR"/${LGPFX}subscribe_rabbitmqtt_f31_*.log | grep -v DEBUG | wc -l`"
  fi
  totsubrmqtt="${tot}"

  countthem "`grep -aE "$all_events" "$LOGDIR"/${LGPFX}subscribe_u_sftp_f60_*.log | grep -v DEBUG | wc -l`"
  totsubu="${tot}"
  countthem "`grep -aE "$all_events" "$LOGDIR"/${LGPFX}subscribe_cp_f61_*.log | grep -v DEBUG | wc -l`"
  totsubcp="${tot}"

  #countthem "`grep -aE "$no_hardlink_events" "$LOGDIR"/${LGPFX}subscribe_ftp_f70_*.log | grep -v DEBUG | wc -l`"
  if [ "${sarra_py_version:0:1}" == "3" ]; then
      all_events="do_download downloaded ok"
      countthem "`grep -aE "$all_events" "$LOGDIR"/subscribe_ftp_f70_*.log | grep -v DEBUG | wc -l`"
  else
      countthem "`grep -aE "$no_hardlink_events" "$LOGDIR"/sr_subscribe_ftp_f70_*.log | grep -v DEBUG | wc -l`"
  fi
  totsubftp="${tot}"
  countthem "`grep -aE "$all_events" "$LOGDIR"/${LGPFX}subscribe_q_f71_*.log | grep -v DEBUG | wc -l`"
  totsubq="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
       countthem "`grep -a 'putNewMessage published' "$LOGDIR"/poll_f62_*.log | wc -l`"
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
      countthem "`grep -a 'putNewMessage published' "$LOGDIR"/sarra_download_f20_*.log | wc -l`"
  else
      countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/sr_sarra_download_f20_*.log | wc -l`"
  fi
  totsarp="${tot}"

  if [[ ! "$C_ALSO" && ! -d "$SARRAC_LIB" ]]; then
     return
  fi

  countthem "`grep -a '\[INFO\] received:' $LOGDIR/${LGPFX}cpump_pelle_dd1_f04_*.log | wc -l`"
  totcpelle04r="${tot}"

  countthem "`grep -a '\[INFO\] rejecting ' $LOGDIR/${LGPFX}cpump_pelle_dd1_f04_*.log | wc -l`"
  totcpelle04rej="${tot}"

  countthem "`grep -a '\[INFO\] published:' $LOGDIR/${LGPFX}cpump_pelle_dd1_f04_*.log | wc -l`"
  totcpelle04p="${tot}"

  countthem "`grep -a '\[INFO\] received:' $LOGDIR/${LGPFX}cpump_pelle_dd2_f05_*.log | wc -l`"
  totcpelle05r="${tot}"

  countthem "`grep -a '\[INFO\] rejecting ' $LOGDIR/${LGPFX}cpump_pelle_dd2_f05_*.log | wc -l`"
  totcpelle05rej="${tot}"

  countthem "`grep -a '\[INFO\] published:' $LOGDIR/${LGPFX}cpump_pelle_dd2_f05_*.log | wc -l`"
  totcpelle05p="${tot}"

  countthem "`grep -a '\[INFO\] published:' $LOGDIR/${LGPFX}cpump_xvan_f14_*.log | wc -l`"
  totcvan14p="${tot}"

  countthem "`grep -a '\[INFO\] published:' $LOGDIR/${LGPFX}cpump_xvan_f15_*.log | wc -l`"
  totcvan15p="${tot}"

  countthem "`grep -a '\[INFO\] published:' $LOGDIR/${LGPFX}cpost_veille_f34_*.log | wc -l`"
  totcveille="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
      countthem "`grep -a 'do_download downloaded ok' $LOGDIR/subscribe_cdnld_f21_*.log | wc -l`"
  else
      countthem "`grep -a '\[INFO\] file_log downloaded ' $LOGDIR/sr_subscribe_cdnld_f21_*.log | wc -l`"
  fi
  totcdnld="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
      countthem "`grep -a 'do_download downloaded ok' $LOGDIR/subscribe_cfile_f44_*.log | wc -l`"
  else
      countthem "`grep -a '\[INFO\] file_log downloaded ' $LOGDIR/sr_subscribe_cfile_f44_*.log | wc -l`"
  fi
  totcfile="${tot}"

  if [[ $(ls "$LOGDIR"/${LGPFX}shovel_pclean_f90*.log 2>/dev/null) ]]; then
      if [ ${sarra_py_version%%.*} == '3' ]; then
          countthem "`grep -a 'published' "$LOGDIR"/shovel_pclean_f90*.log | wc -l`"
      else 
          countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/sr_shovel_pclean_f90*.log | wc -l`"
      fi
      totpropagated="${tot}"
  else
      totpropagated="0"
  fi

  if [[ $(ls "$LOGDIR"/${LGPFX}shovel_pclean_f92*.log 2>/dev/null) ]]; then
      if [ ${sarra_py_version%%.*} == '3' ]; then
          countthem "`grep -aE '\[INFO\] unlinked [1-3] ' "$LOGDIR"/shovel_pclean_f92*.log | wc -l`"
      else
          countthem "`grep -aE '\[INFO\] unlinked [1-3] ' "$LOGDIR"/sr_shovel_pclean_f92*.log | wc -l`"
      fi
      totremoved="${tot}"
  else
      totremoved="0"
  fi

  # flags when two lines include *msg_log received* (with no other message between them) indicating no user will know what happenned.
  awk 'BEGIN { lr=0; }; /msg_log received/ { lr++; print lr, FILENAME, $0 ; next; }; { lr=0; } '  $LOGDIR/${LGPFX}subscribe_*_f??_??.log  | grep -v '^1 ' >$missedreport
  missed_dispositions="`wc -l <$missedreport`"

}

