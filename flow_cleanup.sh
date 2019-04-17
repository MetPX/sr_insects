#!/bin/bash

. ./flow_utils.sh

export TESTDIR="`pwd`"

echo "Stopping sr..."
if [ ! "$SARRA_LIB" ]; then
    sr stop >$LOGDIR/sr_stop_f99.log 2>&1
else
    "$SARRA_LIB"/sr.py stop >$LOGDIR/sr_stop_f99.log 2>&1
fi
#flow_configs="poll/pulse.conf `cd ../sarra/examples; ls */*f[0-9][0-9].conf` audit/"
#sr_action "Stopping sr..." stop "-l $FLOWLOGFILE"  "$flow_configs"

echo "Cleanup sr..."
if [ ! "$SARRA_LIB" ]; then
    sr cleanup >$LOGDIR/sr_cleanup_f99.log 2>&1
else
    "$SARRA_LIB"/sr.py cleanup >$LOGDIR/sr_cleanup_f99.log 2>&1
fi 

#echo extra lines for the sr_cpump cleanup hanging
#sleep 10
#killall sr_cpump
#echo remove these 2 when corrected

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

remove_if_present=".ftpserverpid .httpserverpid aaa.conf bbb.inc checksum_AHAH.py sr_http.test.anonymous ${LOGDIR}/flow_setup.exchanges.txt ${LOGDIR}/missed_dispositions.report ${LOGDIR}/srposter.log"

rm -f ${remove_if_present}

queues_to_delete="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list queues | awk ' ( NR > 1 )  && /\.sr_.*_f[0-9][0-9].*/ { print $1; }; '`"

touch $LOGDIR/sr_cleanup_f99.log
echo "Deleting queues: $queues_to_delete"
for q in $queues_to_delete; do
    rabbitmqadmin -H localhost -u bunnymaster -p "${adminpw}" delete queue name=$q >>$LOGDIR/sr_cleanup_f99.log 2>&1
done

exchanges_to_delete="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list exchanges | awk ' ( $1 ~ /x.*/ ) { print $1; }; '`"
echo "Deleting exchanges..."
for exchange in $exchanges_to_delete ; do 
   rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv delete exchange name=${exchange} >>$LOGDIR/sr_cleanup_f99.log 2>&1
done

flow_configs="poll/pulse.conf `cd ../sarra/examples; ls */*f[0-9][0-9].conf; ls */*f[0-9][0-9].inc`"
sr_action "Removing flow configs..." remove " " "$flow_configs"

echo "Removing flow config logs..."
echo $flow_configs |  sed 's/ / ;\n rm -f sr_/g' | sed '1 s|^| rm -f sr_|' | sed '/^ rm -f sr_post/d' | sed 's+/+_+g' | sed '/conf[ ;]*$/!d' | sed 's/\.conf/_[0-9][0-9].log\*/g' | (cd $LOGDIR; sh )
rm -f $LOGDIR/sr_audit* $LOGDIR/*f[0-9][0-9].log $LOGDIR/sr_[0-9][0-9].log*

echo "Removing flow cache/state files ..."
echo $flow_configs 'audit/None/*' |  sed 's/ / ; rm $CACHEDIR\//g' | sed 's/^/rm $CACHEDIR\//' | sed 's+\.conf+/*+g' | sh - 2>/dev/null

tests_cache=$CACHEDIR/*_unit_test
echo $tests_cache|  sed 's/ / ; rm -rf /g' | sed 's/^/rm -rf /' | sh

httpdr=""
if [ -f .httpdocroot ]; then
   httpdr="`cat .httpdocroot`"
   if [ "$httpdr" -a -d "$httpdr" ]; then
      echo "Removing document root ( $httpdr )..."
      rm -rf $httpdr
   fi
fi
echo "Done!"
