
. ./flow_include.sh

function zeroreallyok {
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

   if [ "${1}" -gt 0 ]; then
      printf "test %2d FAILURE: ${1} ${3}\n" ${tno}
   else
      printf "test %2d success: ${1} ${3}\n" ${tno}
      passedno=$((${passedno}+1))
   fi
}

passedno=0
tno=0

system_queue_count="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list queues | grep '(amq.|AMQP )' | wc -l`"

queue_cnt="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list queues | awk ' BEGIN {t=0;} (NR > 1)  && /_f[0-9][0-9]/ { t+=1; }; END { print t; };'`"

zeroreallyok "${system_queue_count}" "$queue_cnt" "${queue_cnt} queues found, expected ${system_queue_count} (only system queues) should be here."

echo "rabbitMQ created ${system_queue_count} for itself that we do not use."

# count queues and exchanges before.
./flow_setup.sh declare
# count queues and exchanges after.

qchk 15 "queues existing after declare"

xchk "exchanges extant after declare"

printf "ls ${HOME}: `ls ${HOME}`\n\n" 
pyexamples=${HOME}/work/sarracenia/sarracenia/examples
if [ ! -d "${pyexamples}" ]; then
    pyexamples=${HOME}/Sarracenia/sr3/sarracenia/examples
    if [ ! -d "${pyexamples}" ]; then
        wget https://github.com/MetPX/sarracenia/blob/main/sarracenia/examples/moth_api_producer.py >./moth_api_producer.py
        wget https://github.com/MetPX/sarracenia/blob/main/sarracenia/examples/moth_api_consumer.py >./moth_api_consumer.py
        pyexamples=`pwd`
    fi
fi

printf "running the python example from ($pyexamples}\n\n"
echo " running: python3 ${pyexamples}/moth_api_producer.py amqp://bunnymaster:${adminpw}@localhost  "
python3 ${pyexamples}/moth_api_producer.py amqp://bunnymaster:"${adminpw}"@localhost

python3 ${pyexamples}/moth_api_consumer.py 
consumed_message_count=$?

calcres "${consumed_message_count}" 5 "moth_api_consumer.py example should consume 5 messages."

sleep 5

posted_message_count="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list queues | awk 'BEGIN { t=0; }; ( NR > 1 ) { t+=$2; } END { print t; };'`"

printf "count of messages queued is: ${posted_message_count}\n\n" 

calcres "${posted_message_count}" 1 "moth_api_producer.py should have posted 1 message"

echo "now remove all server-side resources with cleanup"
sr3 --dangerWillRobinson cleanup

queue_cnt="`rabbitmqadmin -H localhost -u bunnymaster -p ${adminpw} -f tsv list queues | awk ' BEGIN {t=0;} (NR > 1)  && /_f[0-9][0-9]/ { t+=1; }; END { print t; };'`"

zeroreallyok "${system_queue_count}" "$queue_cnt" "Expected ${system_queue_count} but there are ${queue_cnt}... only system queues should be here."

configs_extant="`sr3 status | awk  '/^(cpost|cpump|poll|post|report|sarra|sender|shovel|subscribe|watch|flow)/ { print $1; }'  | wc -l`"
sr3 --dangerWillRobinson remove

configs_extant_after="`sr3 status | awk  '/^(cpost|cpump|poll|post|report|sarra|sender|shovel|subscribe|watch|flow)/ { print $1; }'  | wc -l`"

zeroreallyok "${configs_extant_after}" "$configs_extant" "${configs_extant} present before should have been erased, there are ${configs_extant_after} left"

echo "Overall ${passedno} of ${tno} passed (sample size: $staticfilecount) !"


if [ "${passedno}" -gt 0 -a "${passedno}" -eq "${tno}" ]; then
   results=0
else
   results=$(( "${tno}"-"${passedno}" ))
fi

exit ${results}

