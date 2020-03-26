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


export TESTDIR="`pwd`"
#export PYTHONPATH="`pwd`/../"
. ./flow_utils.sh

testdocroot="$HOME/sarra_devdocroot"
testhost=localhost
sftpuser=`whoami`
flowsetuplog="$LOGDIR/flowsetup_f00.log"
unittestlog="$LOGDIR/unit_tests_f00.log"


##if [ -d $LOGDIR ]; then
#    logs2remove=$(find "$LOGDIR" -iname "*.txt" -o -iname "*f[0-9][0-9]*.log")
#    if [ ! -z "$logs2remove" ]; then
#       echo "Cleaning previous flow test logs..."
#       rm $logs2remove
#    fi
#fi

#if [ ! -d "$testdocroot" ]; then
#  mkdir $testdocroot
  #cp -r testree/* $testdocroot
#  mkdir $testdocroot/downloaded_by_sub_amqp
#  mkdir $testdocroot/downloaded_by_sub_u
#  mkdir $testdocroot/sent_by_tsource2send
#  mkdir $testdocroot/recd_by_srpoll_test1
#  mkdir $testdocroot/posted_by_srpost_test2
#  mkdir $testdocroot/posted_by_shim
#  mkdir $testdocroot/cfr
#  mkdir $testdocroot/cfile
#fi

lo="`netstat -an | grep '127.0.0.1:8001'|wc -l`"
while [ ${lo} -gt 0 ]; do
   echo "Waiting for $lo leftover sockets to clean themselves up from last run."
   sleep 10 
   lo="`netstat -an | grep '127.0.0.1:8001'|wc -l`"
   sleep 5 
done

mkdir -p "$CONFDIR" 2> /dev/null

passed_checks=0
count_of_checks=0


testrundir="`pwd`"

echo "running self test ... takes a minute or two"

cd ${TESTDIR}
echo "Unit tests ("`date`")" > $unittestlog

nbr_test=0
nbr_fail=0

count_of_checks=$((${count_of_checks}+1))

for t in sr_config sr_sarra; do
    echo "======= Testing: "${t}" (unittest)"  >>  $unittestlog
    nbr_test=$(( ${nbr_test}+1 ))
    python3 -m unittest -v ${TESTDIR}/unit_tests/${t}_unit_test.py >> $unittestlog 2>&1
    status=${?}
    if [ $status -ne 0 ]; then
       echo "======= Testing "${t}" (unittest): Failed"
    else
       echo "======= Testing "${t}" (unittest): Succeeded"
    fi

    nbr_fail=$(( ${nbr_fail}+${status} ))
done


for t in sr_cache sr_consumer sr_credentials sr_instances sr_http sr_pattern_match sr_retry sr_sftp sr_util; do
    echo "======= Testing: "${t}  >>  $unittestlog
    nbr_test=$(( ${nbr_test}+1 ))
    ${TESTDIR}/unit_tests/${t}_unit_test.py >> $unittestlog 2>&1
    status=${?}
    if [ $status -ne 0 ]; then
       echo "======= Testing "${t}": Failed"
    else
       echo "======= Testing "${t}": Succeeded"
    fi

    nbr_fail=$(( ${nbr_fail}+${status} ))
done

if [ $nbr_fail -ne 0 ]; then
   echo "FAILED: "${nbr_fail}" self test did not work"
   echo "        Have a look in file "$unittestlog
else
   echo "OK, as expected "${nbr_test}" tests passed"
   passed_checks=$((${passed_checks}+1))
fi

cd $testrundir

if [ ${#} -ge 1 ]; then
export MAX_MESSAGES=${1}
echo $MAX_MESSAGES
fi

if [ $passed_checks = $count_of_checks ]; then
   echo "Overall: PASSED $passed_checks/$count_of_checks checks passed!"
else
   echo "Overall: FAILED $passed_checks/$count_of_checks passed."
fi
