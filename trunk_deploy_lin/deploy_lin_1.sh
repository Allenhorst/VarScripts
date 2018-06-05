## syslogTest / Notifications test

#!/bin/bash
OS_VERSION=`cat /etc/os-release | grep "VERSION_ID" | awk -F= '{print $2}'`
new=\"42.3\"
old=\"13.1\"


ifconfig

logdir=/mnt/E/test/Results
mkdir -p $logdir

/sbin/SuSEfirewall2 off

##if working on new Suse
if [ "$OS_VERSION" == "$new" ]; then
	systemctl stop SuSEfirewall2
	systemctl disable SuSEfirewall2
	systemctl stop postfix
	

	cp /mnt/E/test/main.cf /etc/postfix/
	cp /mnt/E/test/master.cf /etc/postfix/
	
	cp /mnt/E/test/remote.conf /etc/rsyslog.d/
	cp /mnt/E/test/rsyslog.conf /etc/

	systemctl start postfix
	systemctl restart rsyslog
fi


if [ "$OS_VERSION" == "$old" ]; then
	
	aptitude -y install rsyslog
	aptitude -y install --no-recommends --force-resolution postfix

	/etc/init.d/postfix start
	cp /mnt/E/test/main.cf /etc/postfix/
	cp /mnt/E/test/master.cf /etc/postfix/
	
	cp /mnt/E/test/remote.conf /etc/rsyslog.d/
	cp /mnt/E/test/rsyslog.conf /etc/

	/etc/init.d/postfix stop
	/etc/init.d/postfix start

	/sbin/rsyslogd

fi




