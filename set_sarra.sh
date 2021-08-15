
if [ ! "$sarra_py_version" ]; then
    if which sr3 >/dev/null; then
        sarra_py_version="`sr3 -v| grep -v DEVELOPMENT 2>/dev/null`"
    else
        sarra_subscribe_binary="`which sr_subscribe`"
        if [ ! "${sarra_subscribe_binary}" ]; then
           echo "No Sarra python package available. Cannot test."
           exit 2
        fi
        sarra_py_version="`sr_subscribe -h |& awk ' /^version: / { print $2; };'`"
    fi
fi

#echo "sr_subscribe is: ${sarra_subscribe_binary}, version: ${sarra_py_version} "
IFS=.; read -a sarra_py_version <<<"${sarra_py_version}"
IFS=' '

if [ ${sarra_py_version[0]} -eq 2 ]; then
    sarra_cpump_binary="`which sr_cpump`"
    LGPFX="sr_"
else
    sarra_cpump_binary="`which sr3_cpump`"
    LGPFX=""
fi

sarra_c_version="`${sarra_cpump_binary} -h |& awk ' /^usage:/ { print $3; };'`"
#echo "sr c is: ${sarra_cpump_binary}, PFX=${LGPFX} version: ${sarra_c_version} "
IFS=.; read -a sarra_c_version <<<"${sarra_c_version}"
IFS=' '

if [ ! "${SR_DEV_APPNAME}" ]; then
    if [ "${sarra_py_version:0:1}" == "3" ]; then
        export SR_DEV_APPNAME=sr3
    else
        export SR_DEV_APPNAME=sarra
    fi
fi

#echo "appname is: $SR_DEV_APPNAME (used to set conf and cache dirs.)"
#echo "sarra python: $sarra_py_version, c $sarra_c_version"

