#!/bin/bash

. ./flow_include.sh

if [ "$1" ]; then
   smin=$1
else
   smin=1000
fi

countall

snum=1

printf "Initial v3 sample building sample size ${totsarra} need at least ${smin} \n"

while [ "${totsarra}" == 0 ]; do
   sleep 10
   countthem "`grep -a "log after_post posted" "$LOGDIR"/sarra_download_f20_*.log | wc -l`"
   totsarra="${tot}"
   printf "Waiting to start...\n"
done
printf "Done Waiting (sample now:${totsarra})\n"

while [ "${totsarra}" -lt "${smin}" ]; do

    if [ ! "$SARRA_LIB" ]; then

       if [ "`sr3 status shovel/t_dd1_f00 |& tail -1 | awk ' { print $2 } '`" == 'stopped' ]; then 
          echo "Starting shovels and waiting..."
          sr3 start shovel/t_dd1_f00 &
          sr3 start shovel/t_dd2_f00
          if [ "$SARRAC_LIB" ]; then
             "$SARRAC_LIB"/sr3_cpump start pelle_dd1_f04 &
             "$SARRAC_LIB"/sr3_cpump start pelle_dd2_f05             
          elif [ "${C_ALSO}" ]; then
             sr3_cpump start pelle_dd1_f04 &
             sr3_cpump start pelle_dd2_f05
          fi
       fi
   else
       
       if [ "`"$SARRA_LIB"/sr.py status shovel/t_dd1_f00 |& tail -1 | awk ' { print $2 } '`" == 'stopped' ]; then 
          echo "Starting shovels and waiting..."
          "$SARRA_LIB"/sr.py start shovel/t_dd1_f00 &
          "$SARRA_LIB"/sr.py start shovel/t_dd2_f00 
          if [ "$SARRAC_LIB" ]; then
             "$SARRAC_LIB"/sr3_cpump start pelle_dd1_f04 &
             "$SARRAC_LIB"/sr3_cpump start pelle_dd2_f05  
          elif [ "${C_ALSO}" ]; then
             sr3_cpump start pelle_dd1_f04 &
             sr3_cpump start pelle_dd2_f05
          fi  
       fi
   fi
 
   sleep 45
   countall

   printf  "Sample now: %6d Missed_dispositions:%d\n"  "$totsarra" "$missed_dispositions"

done
printf  "\nSufficient!\n" 

# if msg_stopper plugin is used this should not happen
if [ ! "$SARRA_LIB" ]; then
   if [ "`sr3 status shovel/t_dd1_f00 |& tail -1 | awk ' { print $2 } '`" != 'stopped' ]; then 
       echo "Stopping shovels and waiting..."
       sr3 stop shovel/t_dd2_f00
       sr3 stop shovel/t_dd1_f00 
   fi
else 
   if [ "`$SARRA_LIB/sr.py statis shovel/t_dd1_f00|& tail -1 | awk ' { print $2 } '`" != 'stopped' ]; then
       echo "Stopping shovels and waiting..."
       "$SARRA_LIB"/sr.py stop shovel/t_dd2_f00
       "$SARRA_LIB"/sr.py stop shovel/t_dd1_f00
   fi
fi

if [ "$SARRAC_LIB" ]; then
   "$SARRAC_LIB"/sr3_cpump stop pelle_dd1_f04
   "$SARRAC_LIB"/sr3_cpump stop pelle_dd2_f05
elif [ "${C_ALSO}" ]; then
   sr3_cpump stop pelle_dd1_f04
   sr3_cpump stop pelle_dd2_f05
fi

sleep 10

if [ ! "$SARRA_LIB" ]; then
    cmd="`sr3 status shovel/t_dd1_f00|& tail -1 | awk ' { print $2 } '`"
else
    cmd="`"$SARRA_LIB"/sr.py status shovel/t_dd1_f00 |& tail -1 | awk ' { print $2 } '`"
fi

if [ $cmd == 'stopped' ]; then 

   stalled=0
   stalled_value=-1
   retry_msgcnt="`cat "$CACHEDIR"/*/*_f[0-9][0-9]/*retry* 2>/dev/null | sort -u | wc -l`"
   #while [ $retry_msgcnt -gt $(($smin * 20 / 100)) ]; do
   while [ "$retry_msgcnt" -gt 0 ]; do
        printf "Still %4s messages to retry, waiting...\r" "$retry_msgcnt"
        sleep 10
        retry_msgcnt="`cat "$CACHEDIR"/*/*_f[0-9][0-9]/*retry* 2> /dev/null | sort -u | wc -l`"

        if [ "${stalled_value}" == "${retry_msgcnt}" ]; then
              stalled=$((stalled+1));
              if [ "${stalled}" == 5 ]; then
                 printf "\n    Warning some retries stalled, skipping..., might want to check the logs\n\n"
                 retry_msgcnt=0
              fi
        else
              stalled_value=$retry_msgcnt
              stalled=0
        fi

   done

   #queued_msgcnt="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list queues | awk ' BEGIN {t=0;} (NR > 1)  && /_f[0-9][0-9]/ { t+=$(23); }; END { print t; };'`"
   queued_msgcnt="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list queues | awk ' BEGIN {t=0;} (NR > 1)  && /_f[0-9][0-9]/ { t+=$2; }; END { print t; };'`"
   while [ $queued_msgcnt -gt 0 ]; do
        queues_with_msgs="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list queues | awk ' BEGIN {t=0;} (NR > 1)  && /_f[0-9][0-9]/ && ( $2 > 0 ) { print $1; };'`"
        printf "Still %4s messages (in queues: %s) flowing, waiting..." "$queued_msgcnt" "$queues_with_messages"
        sleep 35
        queued_msgcnt="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list queues | awk ' BEGIN {t=0;} (NR > 1)  && /_f[0-9][0-9]/ { t+=$2; }; END { print t; };'`"
   done
   echo "No messages left in queues..."

fi

#need_to_wait="`grep heartbeat config/*/*.conf| awk ' BEGIN { h=0; } { if ( $2 > h ) h=$2;  } END { print h*2; }; '`"
need_to_wait=180
echo "No messages left in queues... wait 2* maximum heartbeat ( ${need_to_wait} ) of any configuration to be sure it is finished."

sleep ${need_to_wait}

printf "\n\nflow test v3 stopped at $totsarra (limit: $smin)\n\n"

