#!/bin/bash

# make sure libsrshim is off

# if running local sarra/sarrac versions, specify path to them with 
# $SARRA_LIB and $SARRAC_LIB, and $SR_POST_CONFIG 
# contains the path to shim_f63.conf (usually in $CONFDIR/cpost/
# shimpost.conf, but specify if otherwise)
# defaults:
#export SR_POST_CONFIG="$CONFDIR/post/shim_f63.conf"
#export SARRA_LIB=""
#export SARRAC_LIB=""


#export PYTHONPATH="`pwd`/../"
. ../flow_utils.sh

testdocroot="$HOME/sarra_devdocroot"
testhost=localhost
sftpuser=`whoami`
flowsetuplog="$LOGDIR/flowsetup_f00.log"


if [ -d $LOGDIR ]; then
    logs2remove=$(find "$LOGDIR" -iname "*.txt" -o -iname "*f[0-9][0-9]*.log")
    if [ ! -z "$logs2remove" ]; then
       echo "Cleaning previous flow test logs..."
       rm $logs2remove
    fi
fi

if [ ! -d "$testdocroot" ]; then
  mkdir $testdocroot
  cp -r testree/* $testdocroot
  mkdir $testdocroot/downloaded_by_sub_amqp
  mkdir $testdocroot/downloaded_by_sub_u
  mkdir $testdocroot/sent_by_tsource2send
  mkdir $testdocroot/recd_by_srpoll_test1
  mkdir $testdocroot/posted_by_srpost_test2
  mkdir $testdocroot/posted_by_shim
  mkdir $testdocroot/cfr
  mkdir $testdocroot/cfile
fi

lo="`netstat -an | grep '127.0.0.1:8001'|wc -l`"
while [ ${lo} -gt 0 ]; do
   echo "Waiting for $lo leftover sockets to clean themselves up from last run."
   sleep 10 
   lo="`netstat -an | grep '127.0.0.1:8001'|wc -l`"
   sleep 5 
done

mkdir -p "$CONFDIR" 2> /dev/null

#flow_configs="`cd ${SR_CONFIG_EXAMPLES}; ls */*f[0-9][0-9].conf; ls */*f[0-9][0-9].inc`"
flow_configs="`cd ${SR_TEST_CONFIGS}; ls */*f[0-9][0-9].inc; ls */*f[0-9][0-9].conf`"

# this one pulls in stuff from package examples, need to get them from config sub-dir.
#sr_action "Adding flow test configurations..." add " " ">> $flowsetuplog 2>\\&1" "$flow_configs"

# this one invokes sr_${component} properly, but there is a bug #298 , so it still doesn't work.
#for i in $flow_configs; 
#do  
#   IFS=/;read -ra thing <<<$i; IFS=' '
#   component=${thing[0]}; cfg=${thing[1]}; 
#   if [ "${SARRA_LIB}" ]; then
#      cmd="${SARRA_LIB}/sr"
#   else 
#      cmd="sr"
#   fi
#   eval  "${cmd}_${component} add ${SR_TEST_CONFIGS}/$i "
#done

echo "Adding flakey broker flow test configurations..."
cd ${SR_TEST_CONFIGS} ; cp -r *  ${HOME}/.config/sarra
cd ..
if [ "${sarra_py_version:0:1}" == "3" ]; then
   if [  "${sarra_py_version:5:2}" -ge "54" ]; then
       sr3 convert ${flow_configs}
   else
       for i in ${flow_configs}; do
           sr3 convert $i
       done
   fi
fi

if [ "$1" == "config" ]; then
    exit 0
fi



passed_checks=0
count_of_checks=0

# ensure users have exchanges:

echo "Initializing with sr_audit... takes a minute or two"
if [ "${sarra_py_version:0:1}" == "3" ]; then
    sr3 --users declare
else
    if [ ! "$SARRA_LIB" ]; then
        sr_audit -debug -users foreground >>$flowsetuplog 2>&1
    else
        "$SARRA_LIB"/sr_audit.py -debug -users foreground >>$flowsetuplog 2>&1
    fi
fi

# Check queues and exchanges
qchk 15 "queues existing after 1st audit"
xchk "exchanges for flow test created"

if [ "$1" = "declare" ]; then
   exit 0
fi

testrundir="`pwd`"

echo "Starting trivial upstream http server on: $SAMPLEDATA, saving pid in .upstreamhttpserverpid"
cd ${SAMPLEDATA}
$testrundir/../trivialserver.py 8090 >>$trivialupstreamhttplog   2>&1 &
upstreamhttpserverpid=$!

echo "Starting trivial downstream http server on: $testdocroot, saving pid in .httpserverpid"
cd $testdocroot
$testrundir/../trivialserver.py >>$trivialhttplog 2>&1 &
httpserverpid=$!


echo "Starting trivial ftp server on: $testdocroot, saving pid in .ftpserverpid"

# note, on older OS, pyftpdlib might need to be installed as a python2 extension.
# 
# note, defaults to port 2121 so devs can start it.

if [ "`lsb_release -rs`" = "14.04"  ]; then
   python -m pyftpdlib >>$trivialftplog 2>&1 &
else
   python3 -m pyftpdlib >>$trivialftplog 2>&1 &
fi
ftpserverpid=$!

sleep 3

if [ ! "`head $trivialftplog | grep 'starting'`" ]; then
   echo "FAILED to start FTP server, is pyftpdlib installed?"
else
   echo "FTP server started." 
   passed_checks=$((${passed_checks}+1))
fi
count_of_checks=$((${count_of_checks}+1))

nbr_test=0
nbr_fail=0

cd $testrundir


echo $ftpserverpid >.ftpserverpid
echo ${upstreamhttpserverpid} >.upstreamhttpserverpid
echo $httpserverpid >.httpserverpid
echo $testdocroot >.httpdocroot
echo $flowpostpid >.flowpostpid

if [ ${#} -ge 1 ]; then
export MAX_MESSAGES=${1}
echo $MAX_MESSAGES
fi

# Start everything but sr_post
#flow_configs="audit/ `cd ${SR_TEST_CONFIGS}; ls */*f[0-9][0-9].conf | ls poll/pulse.conf`"
#sr_action "Starting up all components..." start " " ">> $flowsetuplog 2>\\&1" "$flow_configs"
#echo "Done."

if [ "${sarra_py_version:0:1}" == "3" ]; then
    POST=sr3_post
    CPOST=sr3_cpost
else
    POST=sr_post
    CPOST=sr_cpost
fi
export POST CPOST LGPFX sarra_py_version

echo "Starting flow_post on: $testdocroot, saving pid in .flowpostpid"
./flow_post.sh >$srposterlog 2>&1 &
flowpostpid=$!

echo "starting to post: `date +${SR_DATE_FMT}`"
if [ ! "$SARRA_LIB" ]; then
    $POST --config t_dd1_f00.conf ${SAMPLEDATA} >$LOGDIR/${LGPFX}post_t_dd1_f00_01.log 2>&1 &
    $POST --config t_dd2_f00.conf ${SAMPLEDATA} >$LOGDIR/${LGPFX}post_t_dd2_f00_01.log 2>&1 &
else
    "$SARRA_LIB"/${LGPFX}post.py -config t_dd1_f00.conf ${SAMPLEDATA} >$LOGDIR/${LGPFX}post_t_dd1_f00_01.log 2>&1 &
    "$SARRA_LIB"/${LGPFX}post.py -config t_dd2_f00.conf ${SAMPLEDATA} >$LOGDIR/${LGPFX}post_t_dd2_f00_01.log 2>&1 &
fi

$CPOST -config pelle_dd1_f04.conf >$LOGDIR/${LGPFX}cpost_pelle_dd1_f04_01.log 2>&1 &
$CPOST -config pelle_dd2_f05.conf >$LOGDIR/${LGPFX}cpost_pelle_dd2_f05_01.log 2>&1 &

echo "posting complete: `date +${SR_DATE_FMT}`"

echo "sr starting "
if [ "${sarra_py_version:0:1}" == "3" ]; then
    sr3 start
    ret=$?
else
   sr start
   ret=$?
fi 

count_of_checks=$((${count_of_checks}+1))
if [ $ret -ne 0 ]; then
   echo "FAILED: sr start returned error status"
else
   echo "OK: sr start was successful"
   passed_checks=$((${passed_checks}+1))
fi

abit=45
echo "waiting a bit $abit to let processing get started..."
sleep $abit

if [ $passed_checks = $count_of_checks ]; then
   echo "Overall ${flow_test_name}: PASSED $passed_checks/$count_of_checks checks passed!"
else
   echo "Overall ${flow_test_name}: FAILED $passed_checks/$count_of_checks passed."
fi

