#!/bin/bash
# Copyright 2017 ppoudel@sysgenius.com
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
# Author : Purna Poudel
# Date: 27, 2014
# Version: 1.0
#
#	usage.sh 
# Parses command line arguments and produces usage information.
# This script is being called by other scripts.

function usage {
	printf "Usage: $0 <options>\n";
	printf "Options:\n";
	printf "%10s-c|--rootcontext:%5sRequired. Source path from where log files are read.\n";
	printf "%10s-t|--rpttype%4s:%5sOptional. Values are: 'daily' or 'ondemand'. 'ondemand' is default value.\n";
	printf "%17s               It is used to control logic like whether or not to update historical data files.\n";
  printf "%17s               Only 'daily' option creates and updates historical data files.\n";
	printf "%10s-d|--recorddate%1s:%5sOptional. It is the log entry date. Meaning log entries with that date will be processed.\n";
  printf "%17s               It takes the format 'YYYY-MM-DD'. Default is to use current date. However, if 'daily' is chosen\n";
	printf "%17s               as 2nd argument, and log entry date is not provided, it defaults to 'date - 1 day'.\n";
	printf "%10s-l|--rptloc%5s:%5sOptional. It is report directory where all generated reports are written.\n"
	printf "%17s               Default value is $TMP/<current-date>\n";
	printf "%10s-o|--procoption%1s:%5sOptional. It represents the processing option. Values can be 'full' or 'partial'.\n"
	printf "%17s               Default value is 'partial'. This option is currently being used only for Verbose GC log parser.\n";
		
}

# Default processing option
PO="partial"
# Default report type
rptType="ondemand";
# Default argument name. To produce the full default command line, just in case if user does not pass
# rootcontext option name
co="--rootcontext";
to="--rpttype";
do="--recorddate";
lo="--rptloc";
oo="--procoption";

# Capture current date
currDate=$(date +"%Y-%m-%d");
currSDate=$(date -d $currDate +%s);
parserExeLog=$TMP/parser.log
appendParserLog="true" #if 'false' then creates new parser.log every time.

OPTS=$(getopt -o c:t:d:l:n:o: -l rootcontext:,rpttype:,recorddate:,rptloc:,envname:,procoption: -- "$0" "$@");
if [ $? != 0 ]; then
	echo "Unrecognised command line option encountered.";
	usage;
	exit 1;
fi
eval set -- "$OPTS";

chkRc=$(echo $OPTS | awk '/(--rootcontext |-c )/ {print $0}');
if [[ "$chkRc" == "" ]]; then
	echo "Manadatory option '--rootcontext' or '-c' missing";
	usage;
	exit 1;
fi

# Make sure required argument '--rootcontext' or 'c'
while true; do
	case "$1" in
		-c|--rootcontext)
			co="$1";
			rootcontext=$2;
			shift 2;;				
		-t|--rpttype)
			to="$1";
			rpttype=$2;
			shift 2;;			
		-d|--recorddate)
			do="$1";
			recorddate=$2;
			shift 2;;			
		-l|--rptloc)
			lo="$1";
			rptloc=$2;
			shift 2;;			
		-o|--procoption)
			oo="$1";
			procoption=$2;
			shift 2;;
		--) 
			shift; 
			break;;
	esac
done

if [[ $rootcontext == "" ]]; then
	echo "Valid non empty value for '--rootcontext' or '-c' is required."
	usage;
	exit 1
else
	cmdln="$cmdln $co $rootcontext";
fi

if [[ $rpttype != "" ]]; then
	rptType=`echo $rpttype | awk '{print tolower($0)}' | egrep '(^daily$|^ondemand$)'`
	if [[ $? == 1 ]]; then
		echo "Invalid value '$rpttype' for '--rpttype|-t' Allowed values are: 'daily' or 'ondemand.'";
		usage;
		exit 1;
	fi
fi
cmdln="$cmdln $to $rptType";

if [[ $recorddate != "" ]]; then
	recDate=$(echo $recorddate | egrep '(^[0-9]{4}-[0-1][0-9]-[0-3][0-9]$)')
	if [[ $? == 1 ]]; then
		echo "Invalid value for '--recorddate|-d'. Use date in YYYY-MM-DD format";
		usage;
		exit 1;
	fi
else
	if [[ "$rptType" == "daily" ]]; then
		recDate=$(date -d "-1 day" +"%Y-%m-%d");
	else
		recDate=$currDate;
	fi	
fi
cmdln="$cmdln $do $recDate";

recSDate=$(date -d $recDate +%s);
# Get 3 days old date to be used to find 3 days old log files
_recDate=`date +"%Y%m%d" -d @$recSDate`
recYYYY=`echo $recDate | cut -d'-' -f1`
recYY=`expr substr $recYYYY 3 2`
rec0MM=`echo $recDate | cut -d'-' -f2`
recMM=`echo $rec0MM | sed 's/^0*//'`
#Get localized month like 'Oct' for October
recLM=`date +"%b" -d @$recSDate`
rec0DD=`echo $recDate | cut -d'-' -f3`
recDD=`echo $rec0DD | sed 's/^0*//'`
# Get next day
recNDateSec=`date -d "$recDate 1 day" +%s`
recNDate=`date +"%Y-%m-%d" -d @$recNDateSec`
recNYYYY=`date +"%Y" -d @$recNDateSec`
recNYY=`date +"%y" -d @$recNDateSec`
recN0MM=`date +"%m" -d @$recNDateSec`
recNMM=`echo $recN0MM | sed 's/^0*//'`
recNLM=`date +"%b" -d @$recNDateSec`
recN0DD=`date +"%d" -d @$recNDateSec`
recNDD=`echo $recN0DD | sed 's/^0*//'`

if [[ "$recSDate" -gt "$currSDate" ]]; then
	echo "Supplied value ${recDate} for '--recorddate|-d' is invalid as it is a future date. Enter current date or previous date in YYYY-MM-DD format.";
	usage;
	exit 1;
fi

if [[ $rptloc != "" ]]; then
	rptDir=$rptloc;	
else
	rptDir="$TMP/$recDate";
fi
cmdln="$cmdln $lo $rptDir";

# Processing option to process partial (only for given date) or entire file.
# currently this option is applicable only for gcStatsParser.
# by default it is partial
if [[ $procoption != "" ]]; then
	PO=`echo $procoption | awk '{print tolower($0)}' | egrep '(^full$|^partial$)'`
	if [[ $? == 1 ]]; then
		echo "Unrecognised processing option: '$procoption' supplied as value for '--procoption|-o'. Allowed values are: 'full' or 'partial'";
		usage;
		exit 1
	fi
fi
cmdln="$cmdln $oo $PO";


if [[ ! -e $rptDir ]]; then
    mkdir $rptDir
elif [[ ! -d $rptDir ]]; then
    echo "$rptDir already exists but is not a directory" 1>&2
	exit 1
fi

pDir="$(dirname "$rptDir")"
if [[ "$appendParserLog" == "true" ]]; then
	echo "" >> $parserExeLog;
else
	echo "" > $parserExeLog;
fi