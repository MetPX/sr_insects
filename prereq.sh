
printf "\n\tLooking for the software needed for test suites to run\n\n"
printf "\twill test v3 if it finds it, or v2 if that is available.\n" 
printf "\texport sarra_py_version=x.yy to override autoselection\n"

bash_binary="`which bash`"
if [ ! "${bash_binary}" ]; then
   echo "No Bash! test scripts are mostly bash scripts"
   exit 20
fi
echo "bash is there."

min_rel="16.04"
rel="`lsb_release -rs`"
relid="`lsb_release -is`"
if [[ "${relid}" != "Ubuntu" ]]; then
   echo "Testing on ${relid}"	
elif [[ "${rel}" < "${min_rel}" ]]; then
   echo "Require ubuntu at least ${min_rel}.  Comment this part out of prereq.sh if running in other environments."
   echo "it is a shorthand to avoid running on environments that are too old."
   exit 30
else
   echo "Ubuntu is modern."
fi
 
awk_binary="`which awk`"
if [ ! "${awk_binary}" ]; then
   echo "No awk! test scripts use awk"
   exit 21
fi
echo "awk is there."

sshd_binary="`ps -ef | grep sshd`"
if [ ! "${sshd_binary}" ]; then
   echo "No sshd! test scripts use awk"
   exit 22
fi
echo "sshd is there."


python_binary="`which python3`"
if [ ! "${python_binary}" ]; then
   echo "No python3! Need full python3 environment"
   exit 22
fi

pyver="`python3 -V|awk '{ print $2; };'`"
echo "python3 is is: ${python_binary}, version: ${pyver} "

OLDIFS=${IFS}
IFS=.; read -a pyver <<<"${pyver}"
IFS=${OLDIFS}


if [ ${pyver[0]} -lt 3 ];  then
   echo "Python3 interpreter must be >= 3.5"
   exit 3
elif [  ${pyver[0]} -eq 3 -a ${pyver[1]} -lt 5 ];  then
   echo "python interpreter >= 3.5"
   exit 4
fi


echo "OK, basic scripting environment is there"

if [ -f set_sarra.sh ]; then
   . ./set_sarra.sh
else
   . ../set_sarra.sh
fi

if [ ${sarra_py_version[0]} -lt 2 ];  then
   echo "metpx-sarracenia Python package must be >= 2.20"
   exit 3
elif [ "${sarra_py_version[0]}" -eq 2 -a "${sarra_py_version[1]}" -lt 20 ];  then
   echo "metpx-sarracenia Python package must >= 2.20.b2"
   exit 4
fi

if [ ! "${sarra_cpump_binary}" ]; then
   echo "No Sarra C package available. Cannot test."
   exit 1
fi

if [ ${sarra_c_version[0]} -lt 2 ];  then
       echo "sarrac C-binary package must be >= 2.20"
       exit 5
elif [  ${sarra_c_version[0]} -eq 2 -a ${sarra_c_version[1]} -lt 20 ];  then
       echo "sarrac C-binary package must >= 2.20.b3"
       exit 6
fi

echo "OK, sarra related prerequisites seem to be there."

if [ -f python_req.py ]; then
   pyreq=python_req.py
elif [ -f ../python_req.py ]; then
   pyreq=../python_req.py
else
   echo "no python prereq test script found"
   exit 7
fi
    
python3 $pyreq
status=$?

if [ $status -ne 0 ]; then
  exit $status
fi

printf "\n\tOK, All obvious prerequisites seem to be there.\n\n"
exit 0
