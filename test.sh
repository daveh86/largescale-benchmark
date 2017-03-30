#!/bin/sh

# Steering
COLLECTIONS=100000
THREADS=64
RUNTIME=3600
COL_PER=$(expr $COLLECTIONS / $THREADS)
INTERVAL=$(expr $RUNTIME / 2 / $THREADS)
DOCS_PER=10000000
WORK_DIR=`pwd`
LOG_DIR=$WORK_DIR/log
# Maybe this should be sensible as this would be * $threads for gross ops
OPS_PER_SEC=1000
DBNAME="testdb"
COLNAME="testcol"

#MongoDB steering
DBPATH=$WORK_DIR/dbpath
MONGOD=./mongodb/bin/mongod

# POC Driver Steering
POC_DIR=POCDriver/

echo "we are running $threads threads, which will make $COLLECTIONS collections, adding $COL_PER collections every $INTERVAL seconds"

# We assume we have maven, and java installed and in the users path already for now
function build_poc_tool {
	git clone https://github.com/johnlpage/POCDriver
	cd $POC_DIR
	mvn clean package
	cd $WORK_DIR
}

function standup {
	if [ ! -d  $LOG_DIR ]; then
		mkdir $LOG_DIR
	fi
	if [ -d  $DBPATH ]; then
		rm -rf $DBPATH
	else
		mkdir $DBPATH	
	fi
	$MONGOD --dbpath $DBPATH --logpath $LOG_DIR/mongod.log --fork
}

function teardown {
	pkill java
	pkill mongod
}


#MAIN
build_poc_tool
standup

go=true
live_threads=0
last_standup=1
start=`date +%s`
while $go; do
	now=`date +%s`
	passed=$(expr $now - $start)
	if [ $live_threads -le $THREADS ]; then
		launch_window=$(expr $now - $last_standup)
		if [ $launch_window -gt $INTERVAL ]; then
			last_standup=$now
			coll="$COLNAME-$live_threads"
			# Spawn a worker
			java -jar $POC_DIR/bin/POCDriver.jar -z $DOCS_PER -y $COL_PER -n $DBNAME.$coll -q $OPS_PER_SEC -t 1 > $LOG_DIR/worker-$live_threads.log &
			((live_threads++))
		fi
	fi
	if [ $passed -gt $RUNTIME ]; then
		go=false
	fi
	sleep 1
done
teardown

