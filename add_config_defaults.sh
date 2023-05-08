cat >> ~/.config/sarra/default.conf << EOF
declare env FLOWBROKER=localhost
declare env SFTPUSER=${USER}
declare env TESTDOCROOT=${HOME}/sarra_devdocroot
declare env MQP=amqp
declare env several=3
EOF
cp ~/.config/sarra/default.conf ~/.config/sr3



