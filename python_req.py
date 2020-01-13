
"""
  insert tests for modules python required to run tests (that are not 
  dependencies of the sarra packages)

  exit code should be zero if OK.

  exit code should be over 10 if there is a problem (making room for parent 
  shell script to have different exit codes for each missing dependency.)


   
"""
import sys

try:
    import pyftpdlib

except: 
    print('missing python ftpdaemon library')
    sys.exit(10)


try:
    import paramiko

except: 
    print('missing python paramiko library (for scp/sftp testing)')
    sys.exit(10)



print('OK requisite python modules for testing seem to be present')
sys.exit(0)