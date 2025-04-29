#!/bin/bash

# script to be started by flow_setup.sh which runs sr_post in the background.
. ../set_sarra.sh


#adding libcshim posting as well.
# change LD_PRELOAD with path to libsrshim if not using system one
export SR_POST_CONFIG="$CONFDIR/post/shim_f63.conf"
# The directory we run the flow test scripts in...
tstdir="`pwd`"
httpdocroot=`cat $tstdir/.httpdocroot`

if [ ! -d ${httpdocroot} ]; then
   exit
fi

if [ ! -d ${httpdocroot}/posted_by_shim ]; then
   mkdir  ${httpdocroot}/posted_by_shim
fi

if [ ! -d ${httpdocroot}/linked_by_shim ]; then
   mkdir  ${httpdocroot}/linked_by_shim
fi

if [[ ":$SARRA_LIB/../:" != *":$PYTHONPATH:"* ]]; then
    if [ "${PYTHONPATH:${#PYTHONPATH}-1}" == ":" ]; then
        export PYTHONPATH="$PYTHONPATH$SARRA_LIB/../"
    else 
        export PYTHONPATH="$PYTHONPATH:$SARRA_LIB/../"
    fi
fi

# sr_post initial start
srpostdir=`cat $tstdir/.httpdocroot`/sent_by_tsource2send
srpostlstfile=$httpdocroot/srpostlstfile
srpostlstfile_new=$httpdocroot/srpostlstfile.new
srpostlstfile_old=$httpdocroot/srpostlstfile.old

echo > ${srpostlstfile_old}
# sr_post call

function do_sr_links {

   for f in `cat /tmp/diffs.txt`; do
       a=${srpostdir}/$f
       b="`dirname ${httpdocroot}/linked_by_shim/$f`"
       if [ ! -d $b ]; then
            mkdir -p $b
       fi
       ln -s ${a} ${b}
       
   done
}

function do_sr_post {

   cd $srpostdir
   # sr_post testing START
   # TODO - consider if .httpdocroot ends with a '/' ?
   find . -type f -print | grep -v '.tmp$'  > $srpostlstfile
   find . -type l -print | grep -v '.tmp$' >> $srpostlstfile
   cat $srpostlstfile    | sort > $srpostlstfile_new

   # Obtain file listing delta
   rm    /tmp/diffs.txt 2> /dev/null
   touch /tmp/diffs.txt
   comm -23 $srpostlstfile_new $srpostlstfile_old > /tmp/diffs.txt
   srpostdelta=`cat /tmp/diffs.txt`
   # | sed 's/^..//'
   if [ "$srpostdelta" == "" ]; then
    return
   fi

   echo  "FIXME: sarra_py_version=${sarra_py_version} POST=${POST}"
   if [[ ${sarra_c_version} > "3.24.06" ]]; then
	   lib_version="${sarra_c_version}"
   else
	   lib_version="1.0.0"
   fi
   if [ "${POST:2:1}" == "3" ]; then
      SHIMLIB="libsr3shim.so.${lib_version}"
   else
      SHIMLIB="libsrshim.so.${lib_version}"
   fi
   printf "FIXME POST=${POST} \n" 

   if [ ! "$SARRA_LIB" ]; then
    $POST -c test2_f61.conf -p `cat /tmp/diffs.txt`
   else 
    "$SARRA_LIB"/sr_post.py -c "$CONFDIR"/post/test2_f61.conf -p `cat /tmp/diffs.txt`
   fi
   cd $srpostdir  
   if [ "$SARRAC_LIB" ]; then
    LD_PRELOAD="$SARRAC_LIB/${SHIMLIB}" cp -p --parents `cat /tmp/diffs.txt`  ${httpdocroot}/posted_by_shim
    LD_PRELOAD="$SARRAC_LIB/${SHIMLIB}" do_sr_links
   else 
    LD_PRELOAD="${SHIMLIB}" cp -p --parents `cat /tmp/diffs.txt`  ${httpdocroot}/posted_by_shim
    LD_PRELOAD="${SHIMLIB}" do_sr_links
   fi
   
   cp -p $srpostlstfile_new $srpostlstfile_old

}

# sr_post initial end

set -x
while true; do
   sleep 1
   do_sr_post
done

