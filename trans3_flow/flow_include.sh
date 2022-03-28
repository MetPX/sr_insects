#!/bin/bash

. ../flow_utils.sh

C_ALSO="`which sr_cpost`"
# The directory we run the flow test scripts in...
tstdir="`pwd`"
httpdocroot=`cat $tstdir/.httpdocroot`

if [ "${sarra_py_version:0:1}" == "3" ]; then
   LGPFX=""
else
   LGPFX="sr_"
fi

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
   # compare first and second totals, and report agreement if within some percent of one another.
   # see maxerr calculation... 
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
   maxerr=$(( $mean / 1000 ))

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
     to_add="`grep -a "\[INFO\] $pat" $l | tail -1 | awk ' { print $5; }; '`"
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
       countthem "`grep -a 'log post posted' "$LOGDIR"/post_t_dd1_f00_*.log | wc -l`"
  else
       countthem "`grep -a '\[INFO\] post_log' "$LOGDIR"/sr_post_t_dd1_f00_*.log | wc -l`"
  fi
  totshovel1="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
       countthem "`grep -a 'log post posted' "$LOGDIR"/post_t_dd2_f00_*.log | wc -l`"
  else
       countthem "`grep -a '\[INFO\] post_log' "$LOGDIR"/sr_post_t_dd2_f00_*.log | wc -l`"
  fi
  totshovel2="${tot}"

  countthem "`grep -a rejected  "$LOGDIR"/${LGPFX}sarra_download_f20_*.log | grep -v DEBUG | wc -l`"
  totrejected="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
       countthem "`grep -a 'log post posted' "$LOGDIR"/${LGPFX}watch_f40_*.log | wc -l`"
  else
       countthem "`grep -a '\[INFO\] post_log' "$LOGDIR"/${LGPFX}watch_f40_*.log | wc -l`"
  fi
  totwatch="${tot}"

  countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/${LGPFX}sender_tsource2send_f50_*.log | wc -l`"
  if [ "${sarra_py_version:0:1}" == "3" ]; then
      countthem "`grep -a 'log post posted' "$LOGDIR"/${LGPFX}sender_tsource2send_f50_*.log | wc -l`"
      all_events="do_download\ downloaded\ ok|write_inline_file\ data\ inlined\ with\ message"
  else
      countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/${LGPFX}sender_tsource2send_f50_*.log | wc -l`"
      no_hardlink_events='downloaded to:|symlinked to|removed'
      all_events="hardlink|$no_hardlink_events"
  fi
  totsent="${tot}"

  countthem "`grep -aE "$all_events" "$LOGDIR"/${LGPFX}subscribe_u_sftp_f60_*.log | grep -v DEBUG | wc -l`"
  totsubu="${tot}"
  countthem "`grep -aE "$all_events" "$LOGDIR"/${LGPFX}subscribe_cp_f61_*.log | grep -v DEBUG | wc -l`"
  totsubcp="${tot}"
  if [ "${sarra_py_version:0:1}" == "3" ]; then
      all_events="do_download downloaded ok"
      countthem "`grep -aE "$all_events" "$LOGDIR"/${LGPFX}subscribe_ftp_f70_*.log | grep -v DEBUG | wc -l`"
  else
      countthem "`grep -aE "$no_hardlink_events" "$LOGDIR"/${LGPFX}subscribe_ftp_f70_*.log | grep -v DEBUG | wc -l`"
fi
  totsubftp="${tot}"
  countthem "`grep -aE "$all_events" "$LOGDIR"/${LGPFX}subscribe_q_f71_*.log | grep -v DEBUG | wc -l`"
  totsubq="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
       countthem "`grep -a 'log post posted' "$LOGDIR"/${LGPFX}poll_f62_*.log | wc -l`"
  else
       countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/${LGPFX}poll_f62_*.log | wc -l`"
  fi
  totpoll1="${tot}"

  if [ "${sarra_py_version:0:1}" == "3" ]; then
       countthem "`grep -a 'log post posted' $srposterlog | grep -v shim | wc -l`"
  else
       countthem "`grep -a '\[INFO\] post_log notice' $srposterlog | grep -v shim | wc -l`"
  fi
  totpost1="${tot}"

  countthem "`grep -a '\[INFO\] published:' $srposterlog | grep shim | wc -l`"
  totshimpost1="${tot}"

  #countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/${LGPFX}sarra_download_f20_*.log | wc -l`"
  if [ "${sarra_py_version:0:1}" == "3" ]; then
      countthem "`grep -a 'log after_accept accepted:' "$LOGDIR"/${LGPFX}sarra_download_f20_*.log | wc -l`"
      totsarx="${tot}"
      countthem "`grep -a 'log post posted' "$LOGDIR"/${LGPFX}sarra_download_f20_*.log | wc -l`"
      totsarp="${tot}"
  else
      countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/${LGPFX}sarra_download_f20_*.log | wc -l`"
      totsarp="${tot}"
      countthem "`grep -a 'received' "$LOGDIR"/${LGPFX}sarra_download_f20_*.log | wc -l`"
      totsarx="${tot}"
  fi

  if [[ ! "$C_ALSO" && ! -d "$SARRAC_LIB" ]]; then
     return
  fi
  staticfilecount="`ls -lR ${SAMPLEDATA}/20200105/WXO-DD/bulletins | grep '^-r' | wc -l`"

  if [[ $(ls "$LOGDIR"/${LGPFX}shovel_pclean_f90*.log 2>/dev/null) ]]; then
      countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/${LGPFX}shovel_pclean_f90*.log | wc -l`"
      totpropagated="${tot}"
  else
      totpropagated="0"
  fi

  if [[ $(ls "$LOGDIR"/${LGPFX}shovel_pclean_f92*.log 2>/dev/null) ]]; then
      countthem "`grep -a '\[INFO\] post_log notice' "$LOGDIR"/${LGPFX}shovel_pclean_f92*.log | wc -l`"
      totremoved="${tot}"
  else
      totremoved="0"
  fi

  # flags when two lines include *msg_log received* (with no other message between them) indicating no user will know what happenned.
  awk 'BEGIN { lr=0; }; /msg_log received/ { lr++; print lr, FILENAME, $0 ; next; }; { lr=0; } '  $LOGDIR/${LGPFX}subscribe_*_f??_??.log  | grep -v '^1 ' >$missedreport
  missed_dispositions="`wc -l <$missedreport`"

}

