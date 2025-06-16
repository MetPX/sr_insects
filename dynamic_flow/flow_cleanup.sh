#!/bin/bash


export TESTDIR="`pwd`"

. ../flow_utils.sh

flowlogcleanup="$LOGDIR/flowcleanup_f99.log"
touch $flowlogcleanup

if [ "${sarra_py_version:0:1}" == "3" ]; then
    flow_configs="`cd $CONFDIR; ls */*f[0-9][0-9].conf 2>/dev/null; ls poll/pulse.conf 2>/dev/null`"
    flow_includes="`cd $CONFDIR; ls */*f[0-9][0-9].inc 2>/dev/null; ls poll/pulse.conf 2>/dev/null`"
else
    flow_configs="audit/ `cd $CONFDIR; ls */*f[0-9][0-9].conf 2>/dev/null; ls poll/pulse.conf 2>/dev/null`"
fi
flow_configs="`echo ${flow_configs} | tr '\n' ' '`"

# Stopping sr components
sr_action "Stopping sr..." stop " " ">> $flowlogcleanup 2>\\&1" "$flow_configs"
# Cleanup sr components
sr_action "Cleanup sr..." cleanup " " ">> $flowlogcleanup 2>\\&1" "$flow_configs"

echo "Cleanup trivial http server... "
if [ -f .httpserverpid ]; then
   httpserverpid="`cat .httpserverpid`"
   if [ "`ps ax | awk ' $1 == '${httpserverpid}' { print $1; }; '`" ]; then
       kill $httpserverpid
       echo "Web server stopped."
       sleep 2
   else
       echo "No web server found running from pid file"
   fi

   echo "If other web servers with lost pid kill them"
   pgrep -al python3 | grep trivialserver.py | grep -v grep  | xargs -n1 kill 2> /dev/null

   if [ "`netstat -an | grep LISTEN | grep 8001`" ]; then
       pid="`ps ax | grep trivialserver.py | grep -v grep| awk '{print $1;};'`" 
       echo "Killing rogue web server found on port 8001 at pid=$pid"
       if [ "$pid" ]; then
          kill -9 $pid
       else
          echo "ERROR: could not find web server, but it's running. Look out!"
       fi
  fi
fi

echo "Cleanup trivial ftp server... "
if [ -f .ftpserverpid ]; then
   ftpserverpid="`cat .ftpserverpid`"
   if [ "`ps ax | awk ' $1 == '${ftpserverpid}' { print $1; }; '`" ]; then
       kill $ftpserverpid
       echo "Ftp server stopped."
       sleep 2
   else
       echo "No properly started ftp server found running from pid file"
   fi

   echo "If other ftp servers with lost pid kill them"
   pgrep -al python3 | grep pyftpdlib.py | grep -v grep  | xargs -n1 kill 2> /dev/null

   if [ "`netstat -an | grep LISTEN | grep 2121`" ]; then
       pid="`ps ax | grep ftpdlib | grep -v grep| awk '{print $1;};'`" 
       echo "Killing rogue ftp server on port 2121 found at pid=$pid"
       if [ "$pid" ]; then
          kill -9 $pid
       else
          echo "ERROR: could not find FTP server, but it's running. Look out!"
       fi
  fi
fi

echo "Cleanup flow_post... "
if [ -f .flowpostpid ]; then
   flowpostpid="`cat .flowpostpid`"
   if [ "`ps ax | awk ' $1 == '${flowpostpid}' { print $1; }; '`" ]; then
       kill $flowpostpid
       echo "Flow_post stopped."
       sleep 2
   else
       echo "No properly started flow_post found running from pid file"
   fi

   echo "If other flow_post with lost pid kill them"
   pgrep flow_post.sh  | grep -v grep | xargs -n1 kill 2> /dev/null

fi

# This where we start cleaning the cache
remove_if_present=".ftpserverpid .httpserverpid aaa.conf bbb.inc checksum_AHAH.py sr_http.test.anonymous $exnow $missedreport $srposterlog $trivialftplog $trivialhttplog"
rm -f ${remove_if_present}

queues_to_delete="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list queues | awk ' ( NR > 1 )  && /\.sr_.*_f[0-9][0-9].*/ { print $1; }; '`"

echo "Deleting queues: $queues_to_delete"
for q in $queues_to_delete; do
    rabbitmqadmin -H localhost -u bunnymaster -p "${adminpw}" delete queue name=$q >>$flowlogcleanup 2>&1
done

exchanges_to_delete="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list exchanges | awk ' ( $1 ~ /x.*/ ) { print $1; }; '`"
echo "Deleting exchanges..."
for exchange in $exchanges_to_delete ; do 
   rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv delete exchange name=${exchange} >>$flowlogcleanup 2>&1
done

echo "SR_CONFIG=${SR_TEST_CONFIGS} "
flow_configs="`cd ${SR_TEST_CONFIGS}; ls */*f[0-9][0-9].conf 2>/dev/null; 2>/dev/null; ls poll/pulse.conf 2>/dev/null`"
flow_configs="`echo ${flow_configs} | tr '\n' ' '`"

sr_action "Removing flow configs..." remove " " ">> $flowlogcleanup 2>\\&1" "$flow_configs"

for include_file in ${flow_includes}; do
    rm ~/.config/sr3/${include_file}
done

echo "Removing flow config logs..."
if [ "${sarra_py_version:0:1}" == "3" ]; then
    echo $flow_configs |  sed 's/ / ;\n rm -f /g' | sed '1 s|^| rm -f |' | sed '/^ rm -f post/d' | sed 's+/+_+g' | sed '/conf[ ;]*$/!d' | sed 's/\.conf/_[0-9][0-9].log\*/g' | (cd $LOGDIR; sh )
    echo $flow_configs |  sed 's/ / ;\n rm -f /g' | sed '1 s|^| rm -f |' | sed 's+/+_+g' |  sed '/conf[ ;]*$/!d' | sed 's/\.conf/_[0-9][0-9].json\*/g'| (cd ${LOGDIR}/../metrics; sh )

else
    echo $flow_configs |  sed 's/ / ;\n rm -f sr_/g' | sed '1 s|^| rm -f sr_|' | sed '/^ rm -f sr_post/d' | sed 's+/+_+g' | sed '/conf[ ;]*$/!d' | sed 's/\.conf/_[0-9][0-9].log\*/g' | (cd $LOGDIR; sh )
fi

echo "Removing flow cache/state files ..."
echo $flow_configs | sed 's/ / ; rm $CACHEDIR\//g' | sed 's/^/rm $CACHEDIR\//' | sed 's+\.conf+/*+g' | sh - 2>/dev/null
echo "$CACHEDIR/*_unit_test" |  sed 's/ / ; rm -rf /g' | sed 's/^/rm -rf /' | sh

httpdr=""
if [ -f .httpdocroot ]; then
   httpdr="`cat .httpdocroot`"
   if [ "$httpdr" -a -d "$httpdr" ]; then
      echo "Removing document root ( $httpdr )..."
      rm -rf $httpdr
   fi
fi

sanity_pids="`ps ax | grep -v awk | awk '/while true; do sr3 sanity; sleep/ { print $1; }'`"
if [ "${sanity_pids}" ]; then
   echo "terminating sanity daemon: ${sanity_pids}"
   kill ${sanity_pids}
   sleep 2
   sanity_pids="`ps ax | grep -v awk | awk '/while true; do sr3 sanity; sleep/ { print $1; }'`"
   if [ "${sanity_pids}" ]; then
       echo "SIGKILLING sanity daemon: ${sanity_pids}"
       kill -9 ${sanity_pids}
   fi
fi

echo "Done!"
exit 0
