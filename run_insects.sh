#!/usr/bin/env bash

touch ~/.ssh/authorized_keys
mv ~/.ssh/authorized_keys ~/.ssh/authorized_keys.old

cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod og-wx ~/.ssh/authorized_keys 

for test in unit static_flow; do
   cd $test
   ./flow_setup.sh  # *starts the flows*
   ./flow_limit.sh  # *stops the flows after some period (default: 1000) *
   ./flow_check.sh  # *checks the flows*
   ./flow_cleanup.sh  # *cleans up the flows*
   cd ..
done

mv ~/.ssh/authorized_keys.old ~/.ssh/authorized_keys
