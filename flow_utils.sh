#!/usr/bin/env bash

#SR_TEST_CONFIGS=`sr_subscribe list | awk '  / examples:/ { print $4; }; '`
#export SR_TEST_CONFIGS=`dirname ${SR_TEST_CONFIGS}`

flow_test_name="`pwd`"
flow_test_name="`basename ${flow_test_name}`"

../prereq.sh  >/tmp/prereq.log

if [ $? -ne 0 ]; then
   cat /tmp/prereq.log
   rm /tmp/prereq.log
   exit 1
fi

. ../set_sarra.sh

if [ ! "$sarra_py_version" ]; then
   printf "no sarracenia package found\n"
   exit 2
fi

export TESTDIR="`pwd`"
SAMPLEDATA="`dirname $TESTDIR`"
export SAMPLEDATA=${SAMPLEDATA}/samples/data


SR_TEST_CONFIGS=${TESTDIR}/config

CONFIG_COUNT="`find ${SR_TEST_CONFIGS} -type f -name '*.conf' | wc -l`"

if [ ! "${SR_DEV_APPNAME}" ]; then
    if [ "${sarra_py_version:0:1}" == "3" ]; then
        export SR_DEV_APPNAME=sr3
    else   
        export SR_DEV_APPNAME=sarra
    fi
fi

export SR_DATE_FMT='%Y%m%dT%H%M%s'
NODENAME="`hostname -s`"

function application_dirs {
python3 << EOF

try:
    import appdirs

    cachedir  = appdirs.user_cache_dir('${SR_DEV_APPNAME}','MetPX')
    confdir = appdirs.user_config_dir('${SR_DEV_APPNAME}','MetPX')
    logdir  = appdirs.user_log_dir('${SR_DEV_APPNAME}','MetPX')
    loghostdir  = logdir.replace( 'log', "${NODENAME}/log" )

except:

    import pathlib
    cachedir = str(pathlib.Path.home()) + '/.cache/${SR_DEV_APPNAME}'
    confdir = str(pathlib.Path.home()) + '/.config/${SR_DEV_APPNAME}'
    logdir = str(pathlib.Path.home()) + '/.cache/${SR_DEV_APPNAME}/log'
    loghostdir = str(pathlib.Path.home()) + '/.cache/${SR_DEV_APPNAME}/${NODENAME}/log'


cachedir  = cachedir.replace(' ',r'\ ')
print('export CACHEDIR=%s'% cachedir)

confdir = confdir.replace(' ',r'\ ')
print('export CONFDIR=%s'% confdir)

logdir  = logdir.replace(' ',r'\ ')
print('export LOGDIR=%s'% logdir)

loghostdir  = loghostdir.replace(' ',r'\ ')
print('export LOGHOSTDIR=%s'% loghostdir)

EOF
}


function sr_action {
    msg=$1
    action=$2
    options=$3
    logpipe=$4
    files=$5
    
    echo $msg
    if [ "${sarra_py_version:0:1}" == "3" ]; then

	    count="`sr3 status 2>/dev/null |  awk ' ( $2 ~ /(fore|hung|idle|inte|lag|new|retr|run|stby|stop|wVip)/ ) { print; }; ' | wc -l`"

        if [ "$SARRA_LIB" ]; then
            ${SARRA_LIB}/sr3.py --dangerWillRobinson $count $action $files 
        else
            echo sr3 --dangerWillRobinson ${count} $action $files
            sr3 --dangerWillRobinson ${count} $action $files 
        fi
    else
        if [ "$SARRAC_LIB" ]; then
          echo $files | sed 's/ / ; sr_/g' | sed 's/$/ ;/' | sed 's/^/ sr_/' | sed "s+/+ $action +g" | grep -Po "sr_c[\w]* $action [\w\_\. ]* ;" | sed 's~^~"$SARRAC_LIB"/~' | sh
        else
          echo $files | sed 's/ / ; sr_/g' | sed 's/$/ ;/' | sed 's/^/ sr_/' | sed "s+/+ $action +g" |
          sed "s+ ;+ $logpipe ;+g" | grep -Po "sr_c[\w]* $action [\w\_\. ]* $logpipe ;" | sed 's/ \{2,\}/ /g' | sh
        fi
        if [ "$SARRA_LIB" ]; then
          echo $files | sed 's/ / ; sr_/g' | sed 's/$/ ;/' | sed 's/^/ sr_/' | sed "s+/+ $action +g" | grep -Po "sr_[^c][\w]* $action [\w\_\. ]* ;" | sed 's/ /.py /' | sed 's~^~"$SARRA_LIB"/~' | sh
        else
          echo $files | sed 's/ / ; sr_/g' | sed 's/$/ ;/' | sed 's/^/ sr_/' | sed "s+/+ $options $action +g" | sed "s+ ;+ $logpipe ;+g" | grep -Po "sr_[^c][\w]* $options $action [\w\_\. ]* $logpipe ;" | sed 's/ \{2,\}/ /g' | sh
        fi
    fi
}

function qchk {
    #
    # qchk verify correct number of queues present.
    #
    # 1 - number of queues to expect.
    # 2 - Description string.
    # 3 - query
    #

    echo "list the queues extant:"
    rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list queues
    echo "list the queues extant:"
    rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list bindings

    queue_cnt="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list queues | awk ' BEGIN {t=0;} (NR > 1)  && /_f[0-9][0-9]/ { t+=1; }; END { print t; };'`"

    if [ "$queue_cnt" -ge $1 ]; then
        echo "OK, as expected $1 $2"
        passed_checks=$((${passed_checks}+1))
    else
        echo "NOTICE: expected $1, but there are $queue_cnt $2"
    fi

    count_of_checks=$((${count_of_checks}+1))

}

function xchk {
    #
    # qchk verify correct number of exchanges present.
    #
    # 1 - number of exchanges to expect.
    # 2 - Description string.
    #
    if [ "${sarra_py_version:0:1}" == "3" ]; then
        exex=flow_lists/v3_exchanges_expected.txt
    else
        exex=flow_lists/exchanges_expected.txt
    fi
    echo "list the exchanges extant:"
    rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list exchanges

    rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list exchanges | grep -v '^name' | grep -v amq\. | grep -v direct| sort >$exnow

    x_cnt="`wc -l <$exnow`"
    expected_cnt="`wc -l <$exex`"

    if [ "$x_cnt" -ge $expected_cnt ]; then
        echo "OK, as expected $expected_cnt $1"
        passed_checks=$((${passed_checks}+1))
    else
        echo "NOTICE: expected $expected_cnt, but there are $x_cnt $1"
        printf "Missing exchanges: %s\n" "`comm -23 $exex $exnow`"
    fi
    if [ "$x_cnt" -gt $expected_cnt ]; then
        printf "NOTE: Extra exchanges: %s\n" "`comm -13 $exex $exnow`"
    fi

    count_of_checks=$((${count_of_checks}+1))

}

function timestamp_summarize {
  # print how long the test took
  # each test should write a timestamp at beginning and end to the log directory.
  # this function prints the difference between the two timestamp files.

  beginning=`cat $LOGDIR/timestamp_start.txt`
  ending=`cat $LOGDIR/timestamp_end.txt`

  duration=$(( ${ending} - ${beginning}))

  printf "test ran for $duration seconds\n"

}


# Code execution shared by more than 1 flow test script

#FIXME: puts the path at the end? so if you have multiple, guaranteed to take the wrong one?
#       psilva worry 2019/01
#
if [[ ":$SARRA_LIB/../:" != *":$PYTHONPATH:"* ]]; then
    if [ "${PYTHONPATH:${#PYTHONPATH}-1}" == ":" ]; then
        export PYTHONPATH="$PYTHONPATH$SARRA_LIB/../"
    else
        export PYTHONPATH="$PYTHONPATH:$SARRA_LIB/../"
    fi
fi
eval `application_dirs`

mkdir -p $LOGDIR

if [ ! -f "$CONFDIR"/admin.conf -o ! -f "$CONFDIR"/credentials.conf ]; then
 cat <<EOT
 ERROR:
 test users for each role: tsource, tsub, tfeed, bunnymaster (admin)
 need to be created before this script can be run.
 rabbitmq-server needs to be installed on a machine (FLOWBROKER) with admin account set and
 manually setup in "$CONFDIR"/admin.conf, something like this:

declare env FLOWBROKER=localhost
declare env MQP=amqp
declare env SFTPUSER="`whoami`"
declare env TESTDOCROOT=${HOME}/sarra_devdocroot

broker amqp://tsource@localhost/
admin amqp://bunnymaster@localhost
feeder  amqp://tfeed@localhost
declare source tsource
declare subscriber tsub
declare subscriber anonymous

and "$CONFDIR"/credentials.conf will need to contain something like:

amqp://bunnymaster:PickAPassword@localhost
ftp://anonymous:anonymous@localhost:2121/
amqp://tsource:PickAPassword2@localhost
amqp://tfeed:PickAPassword3@localhost
amqp://tsub:PickAPassword4@localhost
amqp://anonymous:PickAPassword5@localhost
amqps://anonymous:anonymous@dd.weather.gc.ca
amqps://anonymous:anonymous@dd1.weather.gc.ca
amqps://anonymous:anonymous@dd2.weather.gc.ca

EOT
 exit 1
fi

# Shared variables by more than 1 flow test script
adminpw="`awk ' /bunnymaster:.*@localhost/ { sub(/^.*:/,""); sub(/@.*$/,""); print $1; exit }; ' "$CONFDIR"/credentials.conf`"
srposterlog="$LOGDIR/srposter_f00.log"
exnow=$LOGDIR/flow_setup.exchanges.txt
missedreport="$LOGDIR/missed_dispositions.report"
trivialhttplog="$LOGDIR/trivialhttpserver_f00.log"
trivialftplog="$LOGDIR/trivialftpserver_f00.log"
trivialupstreamhttplog="$LOGDIR/trivialupstreamhttpserver_f00.log"


MQP="`grep -v '^#' ~/.config/sr3/default.conf | grep 'declare env MQP=' | sed 's/.*MQP=//'`"
