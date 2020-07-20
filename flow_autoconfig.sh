# Flow Test Autoconfig
#
# Script meant to be run on fresh installations. Downloads dependencies
#  and configures a RabbitMQ broker for running sr_insects tests.
#
# WARNING: May break current sarracenia configurations on system.
#
# RabbitMQ web console can be accessed at: http://localhost:15672
# Credentials for log-in are created at: ~/.config/sarra/credentials.conf
#
# Tested on Ubuntu 18.04

# Install and configure dependencies
echo "-- Installing dependencies --"
sudo apt-key adv --keyserver "hkps.pool.sks-keyservers.net" --recv-keys "0x6B73A36E6026DFCA"
sudo add-apt-repository -y ppa:ssc-hpc-chp-spc/metpx
sudo apt-get update
sudo apt -y install --no-install-recommends rabbitmq-server erlang-nox sarrac librabbitmq4 libsarrac libsarrac-dev openssh-server net-tools

pip install -U pip
pip install pyftpdlib paramiko

# Setup autossh login
echo "-- Enabling autossh login on localhost --"
rm ~/.ssh/id_rsa
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys
ssh -oStrictHostKeyChecking=no localhost "echo ssh connection to localhost successful"

# Setup basic configs
echo "-- Creating configuration files --"
mkdir -p ~/.config/sarra

cat > ~/.config/sarra/default.conf << EOF
declare env FLOWBROKER=localhost
declare env SFTPUSER=${USER}
declare env TESTDOCROOT=${HOME}/sarra_devdocroot
EOF

ADMIN_PASSWORD=$(openssl rand -hex 6)
OTHER_PASSWORD=$(openssl rand -hex 6)
cat > ~/.config/sarra/credentials.conf << EOF
amqp://bunnymaster:${ADMIN_PASSWORD}@localhost/
amqp://tsource:${OTHER_PASSWORD}@localhost/
amqp://tsub:${OTHER_PASSWORD}@localhost/
amqp://tfeed:${OTHER_PASSWORD}@localhost/
amqp://anonymous:${OTHER_PASSWORD}@localhost/
amqps://anonymous:anonymous@dd.weather.gc.ca
amqps://anonymous:anonymous@dd1.weather.gc.ca
amqps://anonymous:anonymous@dd2.weather.gc.ca
amqps://anonymous:anonymous@hpfx.collab.science.gc.ca
ftp://anonymous:anonymous@localhost:2121/
EOF

cat > ~/.config/sarra/admin.conf << EOF
cluster localhost
admin amqp://bunnymaster@localhost/
feeder amqp://tfeed@localhost/
declare source tsource
declare subscriber tsub
declare subscriber anonymous
EOF

# Manage RabbitMQ
echo "-- Configuring the RabbitMQ broker --"
sudo rabbitmq-plugins enable rabbitmq_management

sudo rabbitmqctl delete_user guest

for USER_NAME in "bunnymaster" "tsource" "tsub" "tfeed" "anonymous"; do
sudo rabbitmqctl delete_user ${USER_NAME}
done

sudo rabbitmqctl add_user bunnymaster ${ADMIN_PASSWORD}
sudo rabbitmqctl set_permissions bunnymaster ".*" ".*" ".*"
sudo rabbitmqctl set_user_tags bunnymaster administrator

sudo systemctl restart rabbitmq-server
cd /usr/local/bin
sudo mv rabbitmqadmin rabbitmqadmin.1
sudo wget http://localhost:15672/cli/rabbitmqadmin
sudo chmod 755 rabbitmqadmin

# Configure users
echo "-- Configuring users --"
sr_audit --users foreground

