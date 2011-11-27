#!/bin/sh
PATH=/sbin:/usr/sbin:/bin:/usr/bin
MONGOD=/usr/local/mongo/bin/mongod
DATADIR=/var/lib/mongodb
PIDFILE=$DATADIR/mongod.lock
LOGFILE=/var/log/mongodb.log
EXTRAOPTS=
ENABLED=1

test -x $MONGOD || exit 0

if [ -e /etc/default/mongodb ]; then
	. /etc/default/mongodb
fi

test "$ENABLED" != "0" || exit 0

[ -f /etc/default/rcS ] && . /etc/default/rcS
. /lib/lsb/init-functions


mongodb_start()
{
	start-stop-daemon --start --pidfile "$PIDFILE" \
		--exec $MONGOD -- --fork --logpath $LOGFILE --logappend --dbpath $DATADIR \
		$EXTRAOPTS || return 2
	return 0
}

mongodb_stop()
{
	start-stop-daemon --stop --user root --pidfile "$PIDFILE" \
		|| return 2
	return 0
}

case "$1" in
start)
	log_daemon_msg "Starting mongodb" "mongodb"
	mongodb_start
	case "$?" in
	0)
		log_end_msg 0
		;;
	1)
		log_end_msg 1
		echo "pid file '$PIDFILE' found, mongodb not started."
		;;
	2)
		log_end_msg 1
		;;
	esac
	;;
stop)
	log_daemon_msg "Stopping mongodb" "mongodb"
	mongodb_stop
	case "$?" in
	0|1)
		log_end_msg 0
		;;
	2)
		log_end_msg 1
		;;
	esac
	;;
restart)
	log_daemon_msg "Restarting mongodb" "mongodb"
	mongodb_stop
	mongodb_start
	case "$?" in
	0)
		log_end_msg 0
		;;
	1)
		log_end_msg 1
		;;
	2)
		log_end_msg 1
		;;
	esac
	;;
*)
	echo "Usage: /etc/init.d/mongodb {start|stop|restart}"
	exit 3
	;;
esac

:
