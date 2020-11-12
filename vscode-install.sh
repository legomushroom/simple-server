#!/usr/bin/env bash

start_time_total=`date +%s.%N`

#input
SERVER=$1
COMMIT_ID=$2
UUID=$3
QUALITY=$4
EXTENSIONS=$5
TELEMETRY=$6
echo "|================ vscode-install.sh Arguments ================="
echo "|     SERVER: $SERVER"
echo "|  COMMIT_ID: $COMMIT_ID"
echo "|       UUID: $UUID"
echo "|    QUALITY: $QUALITY"
echo "| EXTENSIONS: $EXTENSIONS"
echo "|  TELEMETRY: $TELEMETRY"
echo "|=============================================================="
#setup
VSCH_HOME="$HOME"
VCSH_TAR="vscode-$SERVER.tar.gz"
VSCH_DIR_ROOT="$VSCH_HOME/.vscode-remote"
VSCH_BIN_DIR="$VSCH_DIR_ROOT/bin"
VSCH_DIR="$VSCH_BIN_DIR/$COMMIT_ID"
VSCH_LOGFILE="$VSCH_HOME/.vscode-remote/.$COMMIT_ID.log"

SERVER_PID=$(ps ax | grep $VSCH_DIR/server.sh | grep -v grep | sed 's@^[^0-9]*\([0-9]\+\).*@\1@')

# reset
kill -9 $SERVER_PID 2> /dev/null;
rm -rf $VSCH_DIR_ROOT 2> /dev/null;
ls -la $VSCH_DIR_ROOT 2> /dev/null;

start_time_beginning=`date +%s.%N`

if [ ! -d "$VSCH_DIR" ]; then
	mkdir -p $VSCH_DIR
fi


## Copyright (C) 2009 Przemyslaw Pawelczyk <przemoc@gmail.com>
## This script is licensed under the terms of the MIT license.
## https://opensource.org/licenses/MIT

get_lockfile() {
	echo "$VSCH_DIR/vscode-remote-lock.$1"
}

# PRIVATE
_lock()             { flock -$1 $2; }
_no_more_locking()  { _lock u $2; _lock xn $2 && rm -f $(get_lockfile $1); }
_prepare_locking()  { eval "exec $2>\\"$(get_lockfile $1)\\""; trap "_no_more_locking $1 $2" EXIT; }
# PUBLIC - all take lock FD
exlock_now()        { _lock xn $1; }  # obtain an exclusive lock immediately or fail
exlock()            { _lock x $1; }   # obtain an exclusive lock
shlock()            { _lock s $1; }   # obtain a shared lock
unlock()            { _lock u $1; }   # drop a lock

LOCKFD=99
CLEANUP_LOCKFD=98
_prepare_locking $COMMIT_ID $LOCKFD

if (( $? > 0 ))
then
	echo "Installation already in progress..."
	echo "$UUID##24##$UUID"
	exit 0
fi

# Keep the newest 5 servers
TO_DELETE=$(ls -1 --sort=time $VSCH_BIN_DIR | tail -n +6)
for COMMIT_TO_DELETE in $TO_DELETE; do
	echo "Found old VS Code install $COMMIT_TO_DELETE, attempting to clean up"

	_prepare_locking $COMMIT_TO_DELETE $CLEANUP_LOCKFD
	exlock_now $CLEANUP_LOCKFD
	if (( $? == 0 )); then
		RUNNING="`ps ax | grep $COMMIT_TO_DELETE | grep -v grep | wc -l | tr -d '[:space:]'`"
		if [ "$RUNNING" = "0" ]; then
			echo "Deleting old install from $VSCH_BIN_DIR/$COMMIT_TO_DELETE"
			rm -rf $VSCH_BIN_DIR/$COMMIT_TO_DELETE
		else
			echo "Install still has running processes, not deleting: $COMMIT_TO_DELETE"
 		fi
	else
		echo "Failed to acquire lock for install, not deleting: $COMMIT_TO_DELETE"
	fi
done

end_time_beginning=`date +%s.%N`
runtime_beginning=$(python -c "print(${end_time_beginning} - ${start_time_beginning})")
echo ">>> prepare time: $runtime_beginning"

start_time_install=`date +%s.%N`

# install if needed
if [ ! -f "$VSCH_DIR/server.sh" ]
then
	echo "Installing..."
	STASHED_WORKING_DIR="`pwd`"
	cd $VSCH_DIR
	which wget &> /dev/null
	if [ $? == 0 ]
	then
		echo "Downloading with wget"
		WGET_ERRORS=$(2>&1 wget -nv -O $VCSH_TAR https://update.code.visualstudio.com/commit:$COMMIT_ID/$SERVER/$QUALITY)
		if [ $? -ne 0 ]; then
			echo $WGET_ERRORS
			echo "$UUID##25##$UUID"
			exit 0
		fi
	else
		which curl &> /dev/null
		if [ $? == 0 ]
		then
			echo "Downloading with curl"
			CURL_OUTPUT=$(2>&1 curl -L -s -S https://update.code.visualstudio.com/commit:$COMMIT_ID/$SERVER/$QUALITY --output $VCSH_TAR -w "%{http_code}")
			if [[ ($? -ne 0) || ($CURL_OUTPUT != 2??) ]]; then
				echo $CURL_OUTPUT
				echo "$UUID##25##$UUID"
				exit 0
			fi
		else
			echo "Neither wget nor curl is installed"
			echo "$UUID##26##$UUID"
			exit 0
		fi
	fi
	tar -xf $VCSH_TAR --strip-components 1
	if [ $? -gt 0 ]
       	then
		echo "WARNING: tar exited with non-0 exit code"
	fi

	# cheap sanity check
	if [ ! -f $VSCH_DIR/node ]
	then
		echo "WARNING: $VSCH_DIR/node doesn't exist. Download/untar may have failed."
	fi
    if [ ! -f "$VSCH_DIR/server.sh" ]
	then
		echo "WARNING: "$VSCH_DIR/server.sh" doesn't exist. Download/untar may have failed."
	fi
	rm $VCSH_TAR
	cd $STASHED_WORKING_DIR
else
	echo "Found existing installation..."
fi

end_time_install=`date +%s.%N`
runtime_install=$(python -c "print(${end_time_install} - ${start_time_install})")
echo ">>> server installation time: $runtime_install"

start_time_launch=`date +%s.%N`

# launch if needed
RUNNING="`ps ax | grep $VSCH_DIR/server.sh | grep -v grep | wc -l | tr -d '[:space:]'`"
if [ "$RUNNING" = "0" ]
then
	# Allow users to customize VS Code environment variables (e.g. via dotfiles)
	if [ -f ~/.env ]
	then
		echo "Adding user-defined environment variables from ~/.env"
		. ~/.env
	fi
	echo "Printing the current remote environment..."
	printenv
	echo "Starting agent..."
	export PATH="$VSCH_DIR/bin:$PATH"
	$VSCH_DIR/server.sh --connectionToken $COMMIT_ID --enable-remote-auto-shutdown $TELEMETRY --port=0 &> $VSCH_LOGFILE < /dev/null &
	stopTime=$((SECONDS+30))
	while (($SECONDS < $stopTime))
	do
		PORT=`cat "$VSCH_LOGFILE" | grep -E 'Extension host agent listening on [0-9]+' | grep -v grep | grep -o -E '[0-9]+'`
		if [[ $PORT != '' ]]
		then
			break
		fi
		echo "Waiting for server log..."
		sleep .5
	done
else
    echo ">>> Found running server..."
	echo "Found running server..."
fi
PORT=`cat "$VSCH_LOGFILE" | grep -E 'Extension host agent listening on [0-9]+' | grep -v grep | grep -o -E '[0-9]+'`
if [[ $PORT == '' ]]
then
	echo "Server did not start successfully. Full server log:"
	cat $VSCH_LOGFILE
fi


end_time_launch=`date +%s.%N`
runtime_launch=$(python -c "print(${end_time_launch} - ${start_time_launch})")
echo ">>> vscode server start time: $runtime_launch"

start_time_running=`date +%s.%N`

# If the server was already running, ensure that it won't shut down in the near future
if [ "$RUNNING" != "0" ]
then
    which wget &> /dev/null
    if [ $? == 0 ]
    then
        echo "Checking server status with wget"
        WGET_ERRORS=$(wget --no-proxy -nv -O - http://127.0.0.1:$PORT/delay-shutdown 2>&1)
        if [ $? -ne 0 ]; then
            echo $WGET_ERRORS
            echo "$UUID##27##$UUID"
            exit 0
        fi
    else
        which curl &> /dev/null
        if [ $? == 0 ]
        then
            echo "Checking server status with curl"
            CURL_OUTPUT=$(curl --noproxy 127.0.0.1 -s http://127.0.0.1:$PORT/delay-shutdown -w " %{http_code}")
            if [[ ($? -ne 0) || ($CURL_OUTPUT != "OK 200") ]]; then
                echo $CURL_OUTPUT
                echo "$UUID##27##$UUID"
                exit 0
            fi
        else
            echo "Neither wget nor curl is installed"
            echo "$UUID##28##$UUID"
            exit 0
        fi
    fi
fi

end_time_running=`date +%s.%N`
runtime_running=$(python -c "print(${end_time_running} - ${start_time_running})")
echo ">>> check if vscode server is running time: $runtime_running"

start_time_extensions=`date +%s.%N`

if [ ! -z "$EXTENSIONS" ]
	then
		echo "Installing extensions..."
		$VSCH_DIR/server.sh $TELEMETRY $EXTENSIONS
fi

end_time_extensions=`date +%s.%N`
runtime_extensions=$(python -c "print(${end_time_extensions} - ${start_time_extensions})")
echo ">>> extension installation time: $runtime_extensions"

start_time_ending=`date +%s.%N`

echo "$UUID==$PORT==$UUID"

unlock $LOCKFD

end_time_ending=`date +%s.%N`
runtime_ending=$(python -c "print(${end_time_ending} - ${start_time_ending})")
echo ">>> finishing time: $runtime_ending"

end_time_total=`date +%s.%N`
runtime_total=$(python -c "print(${end_time_total} - ${start_time_total})")

echo ">>> total time: $runtime_total"
