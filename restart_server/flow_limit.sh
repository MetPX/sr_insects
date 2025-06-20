#!/bin/bash

. ./flow_include.sh

function swap_poll {
   if [ "${sarra_py_version:0:1}" == "3" ]; then
      echo "switching active poll config"
      sr3 stop poll/sftp_f62 poll/sftp_f63
      mv ~/.config/sr3/poll/sftp_f62.conf ~/.config/sr3/poll_save.conf
      cp ~/.config/sr3/poll/sftp_f63.conf ~/.config/sr3/poll/sftp_f62.conf
      mv ~/.config/sr3/poll_save.conf ~/.config/sr3/poll/sftp_f63.conf 
      sr3 start poll/sftp_f62 poll/sftp_f63
   else
      echo "switching active poll config"
      sr stop poll/sftp_f62 poll/sftp_f63
      mv ~/.config/sr/poll/sftp_f62.conf ~/.config/sr/poll_save.conf
      cp ~/.config/sr/poll/sftp_f63.conf ~/.config/sr/poll/sftp_f62.conf
      mv ~/.config/sr/poll_save.conf ~/.config/sr/poll/sftp_f63.conf
      sr start poll/sftp_f62 poll/sftp_f63
   fi
}


if [ "${sarra_py_version:0:1}" == "3" -a "`COLUMNS=200 sr3 show sarra/download_f20 | grep broker=  | sed 's/.*broker=//;s/:.*//' | head -1`" = 'mqtt' ]; then
    mqpbroker=mosquitto
else
    mqpbroker=rabbitmq-server
fi

if [ "${sarra_py_version:0:1}" == "3" ]; then

	echo "stopping server"

	sr3 stop

	sleep 10
	echo "starting server"

	sr3 start

	sleep 10
	swap_poll 

	echo "stopping server"

	sr3 stop

	sleep 10
	echo "starting server"

	sr3 start

	sleep 10
	swap_poll 

	echo "stopping server"

	sr3 stop

	swap_poll 
	sleep 10

	echo "starting server"

	sr3 start

	swap_poll 

else

	echo "stopping server"

	sr stop

	sleep 10
	echo "starting server"

	sr start

	sleep 10
	swap_poll 

	echo "stopping server"

	sr stop

	sleep 10
	echo "starting server"

	sr start

	sleep 10
	swap_poll 

	echo "stopping server"

	sr stop

	swap_poll 
	sleep 10

	echo "starting server"

	sr start

	swap_poll
fi

countall

#optional... look for posting processes to still be running?
#15647 pts/0    S      0:00 /usr/bin/python3 /usr/bin/sr_post -config t_dd1_f00.conf /local/home/peter/src/sr_insects/samples/data
#15648 pts/0    S      0:00 /usr/bin/python3 /usr/bin/sr_post -config t_dd2_f00.conf /local/home/peter/src/sr_insects/samples/data
running=1
count=0
while [ $running -gt 0 ]; do
  # can have sr_post or sr3_post
  running="`ps ax | grep -aE '(sr_post|sr3_post)' | grep t_dd | wc -l`"
  printf "Still posting... %d\n" $count
  count=$((${count}+1))
  sleep 10
done
printf "posting completed...\n"

stalled=0
stalled_value=-1
retry_msgcnt="`cat "$CACHEDIR"/*/*_f[0-9][0-9]/*retry* 2>/dev/null | sort -u | wc -l`"
while [ $retry_msgcnt -gt 0 ]; do
        printf "Still %4s messages to retry, waiting...\n" "$retry_msgcnt"
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
        queues_with_msgs="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list queues | awk ' BEGIN {t=0;} (NR > 1)  && /_f[0-9][0-9]/ && ( $2 > 0 ) { print $1; };' | sed ':a;N;$!ba;s/\\n/, /g' `"
	printf "%s" "$queues_with_msgs" > /tmp/rstest
        printf "${flow_test_name} Still %4s messages (in queues: %s) flowing, waiting...\n" "$queued_msgcnt" "$queues_with_msgs"
        sleep 10
        queued_msgcnt="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list queues | awk ' BEGIN {t=0;} (NR > 1)  && /_f[0-9][0-9]/ { t+=$2; }; END { print t; };'`"
done

need_to_wait="`grep heartbeat config/*/*.conf| awk ' BEGIN { h=0; } { if ( $2 > h ) h=$2;  } END { print h*3; }; '`"
echo "No messages left in queues... wait 3* maximum heartbeat ( ${need_to_wait} ) of any configuration to be sure it is finished."

sleep ${need_to_wait}

date +'%s' >"${LOGDIR}/timestamp_end.txt"

printf "\n\nflow test ${flow_test_name} stopped. \n\n"

