ifconfig

logdir=/mnt/E/test/Results
mkdir -p $logdir

/sbin/SuSEfirewall2 off

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
