#!/bin/bash

. ./flow_include.sh

echo "stopping rabbitmq"
sudo systemctl stop rabbitmq-server
sleep 10
echo "starting rabbitmq"
sudo systemctl start rabbitmq-server
sleep 10

echo "stopping rabbitmq"
sudo systemctl stop rabbitmq-server
sleep 10
echo "starting rabbitmq"
sudo systemctl start rabbitmq-server
sleep 10

echo "stopping rabbitmq"
sudo systemctl stop rabbitmq-server
sleep 10
echo "starting rabbitmq"
sudo systemctl start rabbitmq-server

countall

#optional... look for posting processes to still be running?
#15647 pts/0    S      0:00 /usr/bin/python3 /usr/bin/sr_post -config t_dd1_f00.conf /local/home/peter/src/sr_insects/samples/data
#15648 pts/0    S      0:00 /usr/bin/python3 /usr/bin/sr_post -config t_dd2_f00.conf /local/home/peter/src/sr_insects/samples/data
running=1
count=0
while [ $running -gt 0 ]; do
  running="`ps ax | grep sr_post | grep t_dd | wc -l`"
  printf "Still posting... %d\n" $count
  count=$((${count}+1))
  sleep 10
done
printf "posting completed..."

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
        queues_with_msgs="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list queues | awk ' BEGIN {t=0;} (NR > 1)  && /_f[0-9][0-9]/ && ( $2 > 0 ) { print $1; };'`"
        printf "Still %4s messages (in queues: %s) flowing, waiting...\n" "$queued_msgcnt" "$queues_with_messages"
        sleep 10
        queued_msgcnt="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list queues | awk ' BEGIN {t=0;} (NR > 1)  && /_f[0-9][0-9]/ { t+=$2; }; END { print t; };'`"
done

printf "\n\nflow test stopped. \n\n"

