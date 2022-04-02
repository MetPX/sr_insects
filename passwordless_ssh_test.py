
import os
import paramiko
import sys

config = paramiko.SSHConfig()

with open( os.path.expanduser("~/.ssh/config"), 'r' ) as ssh_config_file :
   config.parse(ssh_config_file)

auth_info = config.lookup('localhost')

print(auth_info)

connection = paramiko.SSHClient()

connection.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    connection.connect( hostname=auth_info['hostname'], username=auth_info['user'], key_filename=auth_info['identityfile'] )
    print( 'ssh localhost with paramiko works.')
except:
    print( 'ssh localhost without password broken!' )   
    sys.exit(1)
