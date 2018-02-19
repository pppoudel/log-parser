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
#	Parses WAS SystemOut.log. 
# Produces Alert.log, Error reports and historical reports.
# If you have logs from multiple Application servers, put corresponding logs under directory named using server name. For example,
# Let's say, you have Application servers 'appSrv01, appSrv02, appSrv03 ... etc.), then put logs from each Application Server under directory like:
# /tmp/appSrv01/
#     SystemOut.log
#	    SystemOut_2017.09.05.log
#	    SystemErr.log
# /tmp/appSrv02/
#     SystemOut.log
#	    SystemOut_2017.09.05.log
#	    SystemErr.log
# Log can be in plain text or tar gzipped. 
#
# Execute as:
# ./websphereLogParser.sh <options>
# Execute below command to see all the available options:
# ./websphereLogParser.sh


# Include usage
source ./usage.sh
echo "==================================================================" 2>&1 | tee -a $parserExeLog
echo "$0 started at: "$(date +"%Y-%m-%dT%H:%M:%S") 2>&1 | tee -a $parserExeLog
echo "Processing logs with the following input command line:" 2>&1 | tee -a $parserExeLog
echo "$cmdln" 2>&1 | tee -a $parserExeLog;

#--------- Input files ---------------#
fTh=./thresholdValues.csv
# Custom error/keyword file to be used as filter.
fFltr="./WASCustomFilter.txt"
#--------- Report/Output files -------#
# These reports are (re) created for each run.
rptAlertFile="$rptDir/00_Alert.txt"
rptWasSummaryFile="$rptDir/01_WASLogSummaryRpt.txt"
rptWasErrFile="$rptDir/WASLogErrRpt_all.csv"
rptWasFilErrFile="$rptDir/WASLogFilteredErrRpt.csv"
rptWasErrSumByErrCmpFile="$rptDir/WASLogSummaryByErrCmpRpt.csv"
rptWasErrSumByErrClsFile="$rptDir/WASLogSummaryByErrClassRpt.csv"
rptWasErrSumByExpFile="$rptDir/WASLogSummaryByErrExpRpt.csv"
rptWasErrSumByMsgFile="$rptDir/WASLogSummaryByErrMsgRpt.csv"
rptWasWarnSumByWarnCmpFile="$rptDir/WASLogSummaryByWarnCmpRpt.csv"
rptWasWarnSumByWarnClsFile="$rptDir/WASLogSummaryByWarnClassRpt.csv"
rptWasWarnSumByExpFile="$rptDir/WASLogSummaryByWarnExpRpt.csv"
rptWasWarnSumByMsgFile="$rptDir/WASLogSummaryByWarnMsgRpt.csv"

#--------- History Report/Output files -------#
# These are historical reports. Each run will append record in existing report file.
rptRecycleHstFile="$pDir/RecycleHistoryRpt_all.csv";

if [[ ! -e $rptRecycleHstFile && $rptType == "daily" ]]; then
	echo "#srv: server" > $rptRecycleHstFile;
	echo "date|srv" >> $rptRecycleHstFile;
fi
rptOomHstFile="$pDir/WASOutOfMemoryHistoryRpt.csv";
if [[ ! -e $rptOomHstFile && $rptType == "daily" ]]; then
	echo "jvm|date|time|details" > $rptOomHstFile;
fi
rptTranTimeOutHstFile="$pDir/WASTransactionTimeOutHistoryRpt.csv";
if [[ ! -e $rptTranTimeOutHstFile && $rptType == "daily" ]]; then
	echo "#tto#: Total number of Transaction TimeOut" > $rptTranTimeOutHstFile;
	echo "date|tto#" >> $rptTranTimeOutHstFile;
fi
rptHungThreadHstFile="$pDir/WASSHungThreadHistoryRpt.csv";
if [[ ! -e $rptHungThreadHstFile && $rptType == "daily" ]]; then
	echo "#nhtc: Number of NEW Hung Thread Count" > $rptHungThreadHstFile;
	echo "#mhtc: Maximum number of Hung Thread Count" >> $rptHungThreadHstFile;
	echo "#rhtc: Remaining number of Hung Thread Count" >> $rptHungThreadHstFile;
	echo "jvm|date|nhtc|mhtc|rhtc" >> $rptHungThreadHstFile;
fi

# find relevant log files.
logFiles=`find $rootcontext -name "SystemOut*" -type f | \
         egrep '(SystemOut.log$|SystemOut.log.zip$|SystemOut.zip$|SystemOut_'$recYY'.'$rec0MM'.'$rec0DD'_.*|SystemOut_'$recNYY'.'$recN0MM'.'$recN0DD'_.*)'`
if [[ "$logFiles" == "" ]]; then
	echo "No log file found. Exiting ...";
	exit 1;
fi
tempWASf=`mktemp`
if [[ -e $fFltr ]]; then
	fltrLn=$(awk -vORS="|" ' $0 !~ /^#.*/ {print $0}' $fFltr | sed -e "s/^/\'(/g" | sed -e "s/|$/)\'/g")
fi

echo "========== Start of WAS Alert Section ==========" >> $rptAlertFile
for z in $logFiles
do
	echo "Started parsing file:" $z 2>&1 | tee -a $parserExeLog
	case "$z" in
		*.zip) 
			unzip -p $z | cat;;
		*.gz)
			gunzip -c $z | cat;;
		*.log)
			cat $z;;
	esac | \
	grep -F "[$recMM/$recDD/$recYY" | awk -vrecMM=$recMM -vrecDD=$recDD -vrecYY=$recYY -vtempWASf=$tempWASf -vfltrLn=$fltrLn -vz=$z \
	'BEGIN{
		FS=" ";
		tsPattern="["recMM"/"recDD"/"recYY".*]";
		OFS=" ";
		split(z,pathTok,"/");
		pName=pathTok[length(pathTok)-1];
		_fName=zTok[length(pathTok)];
		_kwSrchCmd="egrep -i "fltrLn" | xargs -i echo "_fName" "pName" {} >> "tempWASf".filter";
		
	}
	{			
		# Here we only extract the records thats going to be useful for troubleshooting.
		# Warning (E), Error (E), Fatal (F) or any record containing custom keywords defined in keyword filter file 'wasFilter.txt'.
		# for every other record, check first if they start with timestamp
		#\[7/7/15 8:05:47:210 EDT\] 00002082 WASSession    E SessionContextMBeanAdapter findAttCausingNotSerializableException Miscellaneous data: Attribute "objForReport" is declared to be serializable but is found to generate exception "java.io.NotSerializableException" with message "java.util.PropertyResourceBundle".  Fix the application so that the attribute "objForReport" is correctly serializable at runtime.
		# See format details here: https://www.ibm.com/support/knowledgecenter/en/SSAW57_8.5.5/com.ibm.websphere.nd.doc/ae/rtrb_readmsglogs.html
		if($6 ~ /(W|E|F)/ || $7 ~ /(WTRN0006W:|WTRN0124I:|WSVR0001I:|WSVR0001I:)/ || $0 ~ /( WARN | ERROR | FATAL )/){
			print pName,$0 >> tempWASf".process";
		} 
		# Filter few keywords which may come into stack trace lines and ignore everything else
		print $0 | _kwSrchCmd;
				
	}'
	echo "Completed parsing file:" $z 2>&1 | tee -a $parserExeLog
done

# Now, lets feed the file (that is processed in previous step) that has only useful info and relatively small.
cat $tempWASf.process | \
    awk -vfTh=$fTh -vrecDate=$recDate -valrtF=$rptAlertFile -vtempWASf=$tempWASf -vrptType=$rptType \
		-vrptRecycleHstFile=$rptRecycleHstFile -vrptOomHstFile=$rptOomHstFile \
		'BEGIN{
		FS=" ";
		OFS="|";
		# Load the threshold values from ThresholdValues.csv.
		while((getline thln < fTh) > 0){
			# first line is heading. Ignore
			split(thln,arrThln,"|");
			pattern="^was.*";
			if(arrThln[3] ~ pattern){
				#print arrTh[arrThln[1]],arrThln[2]
				#arrTh[arrThln[1]]=arrThln[2];
				arrTh[arrThln[3]"."arrThln[1]]=arrThln[2];
				#print "reading threshold values: " NR, arrThln[1],arrThln[2];				
			}
		}
		close(thln);
		close(fTh);
		print "Server","Date","Time","TZ","Hour","ThreadId","Name","EventType","Details" > tempWASf".was.error.all";
		print "=====================================================" > tempWASf".summary";
		print "===== WAS log analysis report =====" >> tempWASf".summary";
		print "===== based on SystemOut logs dated: " recDate"  =====" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "" >> tempWASf".summary";
		print "===== Summary table contains short heading title. See below for their description =====" >> tempWASf".summary";
		pSFmt="%-5s\t%-70s\n";
		printf pSFmt, "hr",": Hour " >> tempWASf".summary";
		printf pSFmt, "date",": Date " >> tempWASf".summary";		
		printf pSFmt, "time",": Time " >> tempWASf".summary";
		printf pSFmt, "tz",": Time Zone " >> tempWASf".summary";
		printf pSFmt, "woct",": Web or ORB Container Thread" >> tempWASf".summary";
		printf pSFmt, "awoct",": Affected Web or ORB Container Thread(s), may be because of CPU Starvation scheduling dealy" >> tempWASf".summary";
		printf pSFmt, "thid",": Thread ID" >> tempWASf".summary";
		printf pSFmt, "uid",": User ID" >> tempWASf".summary";
		printf pSFmt, "js",": jSession" >> tempWASf".summary";
		printf pSFmt, "rt",": Response Time in Second" >> tempWASf".summary";
		printf pSFmt, "dly",": Delay in second, may be because of CPU Starvation or other causes." >> tempWASf".summary";
		printf pSFmt, "tdly",": Total Delay in second, may be because of CPU Starvation or other causes." >> tempWASf".summary";
		printf pSFmt, "ttov",": Transaction TimeOut Value." >> tempWASf".summary";
		printf pSFmt, "htm",": Hung Thread Hung time in second" >> tempWASf".summary";
		printf pSFmt, "chtc",": Current Hung Thread Count" >> tempWASf".summary";
		printf pSFmt, "nhtc",": Number of NEW Hung Thread Count" >> tempWASf".summary";
		printf pSFmt, "mhtc",": Maximum number of Hung Thread Count" >> tempWASf".summary";
		printf pSFmt, "rhtc",": Remaining number of Hung Thread Count" >> tempWASf".summary";
		printf pSFmt, "cnt",": (Any) Count like jSession count, User count etc. " >> tempWASf".summary";
		printf pSFmt, "trn",": Transaction" >> tempWASf".summary";
		printf pSFmt, "tid",": Transaction ID" >> tempWASf".summary";		
		printf pSFmt, "sts",": Status - Transaction or any status in context " >> tempWASf".summary";
		printf pSFmt, "pc",": (Any) Count or measure represented in Percentage" >> tempWASf".summary";
		printf pSFmt, "jvm",": Java Virtual Machine, may be interchangeably used with was or srv in reports." >> tempWASf".summary";
		printf pSFmt, "was",": WebSphere Application Server" >> tempWASf".summary";
		printf pSFmt, "srv",": server - like web server(IHS), App Server etc." >> tempWASf".summary";
		printf pSFmt, "cmp",": Component" >> tempWASf".summary";
		printf pSFmt, "fnc",": function" >> tempWASf".summary";
		printf pSFmt, "exp",": Exception" >> tempWASf".summary";
		printf pSFmt, "evt",": Event Type like WARNING, ERROR, FATAL etc." >> tempWASf".summary";
		printf pSFmt, "msg",": Message" >> tempWASf".summary";
		printf pSFmt, "lmdl",": Log module" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
	}
	{
		# pName: process/App Server name
		pName=$1;
		#_dt: date
		_dt=substr($2,2); # skips the square bracket in the begining.
		#_tm: time
		_tm=$3;
		_tz=substr($4,1,length($4)-1);
		split(_tm,tsTok,":");
		#_hr: hour of the day
		_hr=tsTok[1];
		#_thId: Thread ID.
		_thId=$5;
		#_fCmp: functional component
		_fCmp=$6;
		#_evtType: event type
		_evtType=$7;
		_sCmp=$8;
		#_expNm: Exception name
		_expNm=$9;
		#_msg: message
		_msg=substr($0,index($0,$10));
		#_dtl: detail
		_dtl=substr($0,index($0,$8));				
		# Print all error records with 
		print pName,_dt,_tm,_tz,_hr,_thId,_fCmp,_evtType,_dtl >> tempWASf".was.error.all";
		# The following are not Warning, Error or Fatal, but Info or Audit messages. However,
		# We are interested because we are tracking transaction timeout messages.
		if(_evtType == "I" || _evtType == "A"){
			switch(_sCmp) {
				case "WTRN0006W:":
					# Get the transactionID and timeout value
					_trnId=$10;
					_tmVal=$(NF-1);
					arrTto[pName"|"_thId]=_tmVal"|"_trnId;
					arrTtoJvm[pName]++;
				break;
				case "WTRN0124I:":
					# Get the transactionID and timeout value
					split(_msg,msgTok,":");
					split(msgTok[2],msgTok1,"]");
					_affcWcs=substr(msgTok1[1],2);
					print pName,_dt,_tm,_tz,_thId,_affcWcs,arrTto[pName"|"_thId] >> tempWASf".tto";
				break;
				case "WSVR0001I:":
					#JVM recycled event, print into JVM recycle history file.
					print pName" recycled at: "_dt " "_tm":"_tz >> alrtF;
					if(rptType == "daily"){
						print _dt,_tm":"_tz,pName >> rptRecycleHstFile;
					}
				break;
			}
		} else {
				
			# Below we are gathering numbers. 
			# create array of event type by JVM
			arrJ[pName"|"_evtType]++;
			# All the evtType
			arrEvtType[_evtType];
			# array of event type by functional component
			arrfCmp[_fCmp"|"_evtType]++;
			# sComponent and evtType
			arrsCmp[_sCmp"|"_evtType]++;
			# by exception and type
			arreXpNm[_expNm"|"_evtType]++;
			# by message and evtType
			arrMsg[_msg"|"_evtType]++;
			#check other errors. Here looking specifically java.lang.OutOfMemoryError 
			if(_msg ~ /.*java\.lang\.OutOfMemoryError.*/){
				#JVM|Date|Time|Details
				arrOOM[pName"|"_dt]=_tm"|"_tz"|"_thId"|"_fCmp"|"_sCmp"|"_expNm"|"_msg;
			}
			switch(_sCmp){
				# Gather statistics about hung threads from hung thread notification.
				case "WSVR0605W:":	
					#\[6/8/15 9:52:53:179 EDT\] 00000089 ThreadMonitor W   WSVR0605W: Thread "WebContainer : 24" (00008a36) has been active for 644907 milliseconds and may be hung.  There is/are 1 thread(s) in total in the server that may be hung.
					#_hWcThread: WebContainer
					_hWcThread=substr($12,1,length($12)-1);
					#_hThID: hung thread thread ID.
					_hThID=substr($13,2,length($13)-2);
					#_hTm: hung time in Seconds.
					_hTm=$18/1000;
					#_hNm: number of hung threads.
					_hNm=$26;
					# hung thread status
					_hStatus="Hung";
					print pName,_dt,_tm,_tz,_hr,_hWcThread,_hThID,_hTm,_hNm,_hStatus >> tempWASf".hung";
				break;
				case "WSVR0606W:":
					# Gather statistics about hung threads from hung thread release notification.
					#\[6/8/15 9:56:18:346 EDT\] 00008a32 ThreadMonitor W   WSVR0606W: Thread "WebContainer : 20" (00008a32) was previously reported to be hung but has completed.  It was active for approximately 889164 milliseconds.  There is/are 8 thread(s) in total in the server that still may be hung.
					#_hWcThread: WebContainer
					_hWcThread=substr($12,1,length($12)-1);
					#_hThID: hung thread thread ID.
					_hThID=substr($13,2,length($13)-2);
					#_hTm: hung time in Seconds.
					_hTm=$28/1000;
					#_hNm: number of hung threads.
					_hNm=$32;
					# hung thread status
					_hStatus="Released";
					print pName,_dt,_tm,_tz,_hr,_hWcThread,_hThID,_hTm,_hNm,_hStatus >> tempWASf".hung";
				break;
				case "HMGR0152W:":
					# gather statistics from CPU Starvation detection notification
					#\[7/7/15 2:08:30:920 EDT\] 00000049 CoordinatorCo W   HMGR0152W: CPU Starvation detected. Current thread scheduling delay is 5 seconds.
					#_scDly: scheduling delay
					_scDly=$(NF-1);
					print pName,_dt,_tm,_tz,_scDly >> tempWASf".cpustarv";
					# Gather total scheduling delay per App Server.
					arrCPUStarvDly[pName]+=_scDly;
					# Gather total (count)scheduling delay per App Server.
					arrCPUStarvCnt[pName]++;			
				break;
				default:
				break;
			}
		}
	
	}END {
		if(length(arrOOM) > 0 ){
			print "" >> tempWASf".summary";
			print "=====================================================" >> tempWASf".summary";
			print "===== Out of Memory Error =====" >> tempWASf".summary";
			print "=====================================================" >> tempWASf".summary";
			print "" >> tempWASf".summary";
			#arrOOM[pName"|"_dt]=_ts"|"_tz"|"_thId"|"_fCmp"|"_sCmp"|"_expNm"|"_msg
			wHdFmt="%-15s\t%-10s\t%-12s\t%-3s\t%-7s\t%-25s\t%-25s\t%-60s\t%-60s\n";		
			printf weJHfmt,"was","date","time","tz","thid","fnc","cmp","exp","msg" >> tempWASf".summary";
			for(eOOM in arrOOM){
				split(eOOM,eOOMTok1,"|");
				split(arrOOM[eOOM],eOOMTok2,"|");
				printf wHdFmt,eOOMTok1[1],eOOMTok1[2],eOOMTok2[1],eOOMTok2[2],eOOMTok2[3],eOOMTok2[4],eOOMTok2[5],eOOMTok2[6],eOOMTok2[7] >> tempWASf".summary";
				print "OutOfMemoryError: ",eOOMTok1[1],eOOMTok1[2],eOOMTok2[1],eOOMTok2[2],eOOMTok2[3],eOOMTok2[4],eOOMTok2[5],eOOMTok2[6],eOOMTok2[7] >>alrtF;
				if(rptType == "daily"){
					print eOOMTok1[1],eOOMTok1[2],eOOMTok2[1],eOOMTok2[2],eOOMTok2[3],eOOMTok2[4],eOOMTok2[5],eOOMTok2[6],eOOMTok2[7] >> rptOomHstFile;
				}
			}
		}
		
		if(length(arrJ) > 0){
			for(_eachJ in arrJ){
				split(_eachJ,eJTok,"|");
				print _eachJ,arrJ[_eachJ] >> tempWASf".errCntBySrv";
				_jvmPrfx=substr(eJTok[1],1,3);
				
				thKeywasFCnt="was."_jvmPrfx".wasFCntTh";
				thValwasFCnt=arrTh[thKeywasFCnt];
				#print "key-thKeywasFCnt:"thKeywasFCnt"; value:"thValwasFCnt;
				
				thKeywasECnt="was."_jvmPrfx".wasECntTh";
				thValwasECnt=arrTh[thKeywasECnt];
				#print "key-thKeywasECnt:"thKeywasECnt"; value:"thValwasECnt;
				
				thKeywasWCnt="was."_jvmPrfx".wasWCntTh";
				thValwasWCnt=arrTh[thKeywasWCnt];
				#print "key-thKeywasWCnt:"thKeywasWCnt"; value:"thValwasWCnt;
				switch(eJTok[2]){
					case /F/:
						if(thValwasFCnt !="" && arrJ[_eachJ] > thValwasFCnt) {
							print arrJ[_eachJ]" : total number of Fatal events on "eJTok[1]" exceed threshold value of "thValwasFCnt >> alrtF;
						}
					break;
					case /E/:
						if(thValwasECnt !="" && arrJ[_eachJ] > thValwasECnt) {
							print arrJ[_eachJ]" : total number of Error events on "eJTok[1]" exceed threshold value of "thValwasECnt >> alrtF;
						}
					break;
					case /W/:
						if(thValwasWCnt !="" && arrJ[_eachJ] > thValwasWCnt) {
							print arrJ[_eachJ]" : total number of WARN events on "eJTok[1]" exceed threshold value of "thValwasWCnt >> alrtF;
						}
					break;
				}				
			}		
		}
		
		#print "=== Sorted by functional component  ====";
		if(length(arrfCmp) > 0){
			for(efcmp in arrfCmp){
				split(efcmp,efcmpTok,"|");
				if(arrfCmp[efcmp] > 0)
					print efcmpTok[2],efcmpTok[1],arrfCmp[efcmp] >> tempWASf".errCntByFncCmp";
			}
		}
		#print "=== Sorted by class component  ====";
		if(length(arrsCmp) > 0){
			for(escmp in arrsCmp){
				split(escmp,escmpTok,"|");
				if(arrsCmp[escmp] > 0)
					#printf weJBfmt,escmpTok[2],escmpTok[1],arrsCmp[escmp] >> tempWASf".errCntByCmp";
					print escmpTok[2],escmpTok[1],arrsCmp[escmp] >> tempWASf".errCntByCmp";
			}
		}
		#print "=== Sorted by class exception  ====";
		if(length(arrXpNm) > 0){
			for(expnm in arrXpNm){
				split(expnm,expnmTok,"|");
				if(arrXpNm[expnm] > 0)
					print expnmTok[2],expnmTok[1],arrXpNm[expnm] >> tempWASf".errCntByExp";
			}
		}
		#print "=== Sorted by message  ====";
		if(length(arrMsg) > 0){
			for(emsg in arrMsg){
				split(emsg,emsgTok,"|");
				if(arrMsg[emsg] > 0)
					print arrMsg[emsg], emsgTok[2],emsgTok[1] >> tempWASf".errCntByMsg";
			}
		}	
		
		if(length(arrTtoJvm) > 0){
			for(ettoj in arrTtoJvm){
				_jvmPrfx=substr(ettoj,1,3);
				thKeyTTOJ="was."_jvmPrfx".wasTranTmOutCntTh";
				thValTTOJ=arrTh[thKeyTTOJ];
				#print "key-thKeyTTOJ:"thKeyTTOJ"; value:"thValTTOJ;
				if(thValTTOJ !="" && arrTtoJvm[ettoj] > thValTTOJ) {
					print arrTtoJvm[ettoj]" : Number transaction time out on "ettoj" exceeds threshold value of "thValTTOJ >> alrtF;
				}
			}
		}
		if(length(arrCPUStarvCnt) > 0){
			for(ecpus in arrCPUStarvCnt) {
				_jvmPrfx=substr(ecpus,1,3);
				thKeyCpuStarvByJVM="was."_jvmPrfx".wasCPUStarvCntTh";
				thValCpuStarvByJVM=arrTh[thKeyCpuStarvByJVM];
				#print "key-thKeyCpuStarvByJVM:"thKeyCpuStarvByJVM"; value:"thValCpuStarvByJVM;
				if(thValCpuStarvByJVM !="" && arrCPUStarvCnt[ecpus] > thValCpuStarvByJVM) {
					print arrCPUStarvCnt[ecpus]" Number thread scheduling delay because of CPU starvation on "ecpus" exceeds threshold value of "thValCpuStarvByJVM >> alrtF;
				}
				print ecpus,arrCPUStarvCnt[ecpus],arrCPUStarvDly[ecpus] >> tempWASf".cpu.summary";				
			}
			
		}
			
	}'

if [[ -e $tempWASf.hung ]]; then
	sort -t'|' -k1,1 -k2,2 -k5,5n -k3,3 -k10,10 $tempWASf.hung | \
	awk -vtempWASf=$tempWASf -vfTh=$fTh -valrtF=$rptAlertFile -vrptType=$rptType -vrecDate=$recDate \
	-vrptHungThreadHstFile=$rptHungThreadHstFile 'BEGIN {
		FS=OFS="|";
		print "" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "===== Hung Thread Details =====" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "" >> tempWASf".summary";
		wHdFmt="%-15s\t%-10s\t%-12s\t%-3s\t%-2s\t%-3s\t%-10s\t%9s\t%5s\t%-8s\n";
		wBdFmt="%-15s\t%-10s\t%-12s\t%-3s\t%-2s\t%-3s\t%-10s\t%6.3f\t%5d\t%-8s\n";
		printf wHdFmt,"was","date","time","tz","hr","woct","thid","htm","chtc","sts" >> tempWASf".summary";
		while((getline thln < fTh) > 0){
			# first line is heading. Ignore
			split(thln,arrThln,"|");
			pattern="^was.*";
			if(arrThln[3] ~ pattern){
				#print arrTh[arrThln[1]],arrThln[2]
				#arrTh[arrThln[1]]=arrThln[2];
				arrTh[arrThln[3]"."arrThln[1]]=arrThln[2];
				#print "reading threshold values: " NR, arrThln[1],arrThln[2];				
			}
		}
		close(thln);
		close(fTh);
	}
	{
		#pName,_dt,_tm,_tz,_hr,_wcThread,_thID,_hTm,_hNm,_hStatus
		printf wHdFmt,$1,$2,$3,$4,$5,$6,$7,$8,$9,$10 >> tempWASf".summary";
		arrRemHThByJVM[$1]=$9;
		arrHThStatus[$1"|"$6"|"$7]=$10;
		if($10 == "Hung"){
			arrNewHthByJVM[$1]++;			
			# record max number of hung threads for the JVM
			maxHth=$9;
			currMaxHth=arrMaxHthByJVM[$1];
			if(currMaxHth != ""){
				if($9 > currMaxHth){
					arrMaxHthByJVM[$1]=$9;
				}
			} else {
				arrMaxHthByJVM[$1]=$9;
			}
		}
	} END {
		print "" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "===== Hung Thread Summary By Server =====" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "" >> tempWASf".summary";
		wHdFmt="%-15s\t%-4s\t%-4s\t%-4s\n";
		wBdFmt="%-15s\t%4d\t%4d\t%4d\n";
		printf wHdFmt,"was","nhtc","mhtc","rhtc" >> tempWASf".summary";
		
		ttlRemSyshCnt=0;
		ttlNewSyshCnt=0;
		ttlAccumSyshCnt=0;
		for(_eJvm in arrNewHthByJVM){
			printf wBdFmt,_eJvm,arrNewHthByJVM[_eJvm],arrMaxHthByJVM[_eJvm],arrRemHThByJVM[_eJvm] >> tempWASf".summary";
			ttlRemSyshCnt+=arrRemHThByJVM[_eJvm];
			ttlNewSyshCnt+=arrNewHthByJVM[_eJvm];
			ttlAccumSyshCnt+=arrMaxHthByJVM[_eJvm];
			_jvmPrfx=substr(_eJvm,1,3);
			thKeyHThByJVM="was."_jvmPrfx".wasHungThrdCntTh";
			thValHThByJVM=arrTh[thKeyHThByJVM];
			#print "key-thKeyHThByJVM:"thKeyHThByJVM"; value:"thValHThByJVM;
			if(thValHThByJVM !="" && arrMaxHthByJVM[_eJvm] > thValHThByJVM) {
				print "Total of "arrMaxHthByJVM[_eJvm]" hung threads on "_eJvm" exceeded threshold value of "thValHThByJVM >> alrtF;
			}
			if(rptType == "daily"){
				print _eJvm,recDate,arrNewHthByJVM[_eJvm],arrMaxHthByJVM[_eJvm],arrRemHThByJVM[_eJvm] >> rptHungThreadHstFile;
			}
		}
		
		print "=====================================================" >> tempWASf".summary";
		print "Total New Hung Threads in the system: "ttlNewSyshCnt >> tempWASf".summary";
		print "Total Max Hung Threads in the system: "ttlAccumSyshCnt >> tempWASf".summary";
		print "Total Hung Threads still remaining in the system: "ttlRemSyshCnt >> tempWASf".summary";
		
		if(ttlRemSyshCnt > 0){
			print "Total "ttlRemSyshCnt" Hung Threads still remaining in the system. Investigate further ..." >> alrtF;
			for (eThSts in arrHThStatus){
				if(arrHThStatus[eThSts] == "Hung"){
					print eThSts >> tempWASf".hth.status";					
				}
			}
		}
		
	}'
fi

if [[ -e $tempWASf.hth.status ]]; then
	sort -t'|' -k1 $tempWASf.hth.status | \
	awk -vtempWASf=$tempWASf 'BEGIN {
		FS=OFS="|";
		print "" >> tempWASf".summary";
		print "Following threads still seem to be hung:" >> tempWASf".summary";
		print "" >> tempWASf".summary";
		wHdFmt="%-15s\t%-3s\t%-10s\n";			
		printf wHdFmt,"was","woct","thid" >> tempWASf".summary";
	} {
		printf wHdFmt,$1,$2,$3 >> tempWASf".summary";		
	}'
fi

if [[ -e $tempWASf.tto ]]; then
	awk -vtempWASf=$tempWASf -vrptType=$rptType -vrptTranTimeOutHstFile=$rptTranTimeOutHstFile 'BEGIN {
		FS=OFS="|";
		print "" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "===== Transaction Timeout =====" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "" >> tempWASf".summary";
		wHdFmt="%-15s\t%-10s\t%-12s\t%-3s\t%-8s\t%-15s\t%-5s\t%-50s\n";
		printf wHdFmt,"was","date","time","tz","thid","awoct","ttov","tid" >> tempWASf".summary";
	}
	{
		printf wHdFmt,$1,$2,$3,$4,$5,$6,$7,$8 >> tempWASf".summary";
		arrTtoByJvm[$1]++;
		
	} END {
		if(length(arrTtoByJvm) > 0){
			ttlTto=0;
			print "" >> tempWASf".summary";
			print "Transaction timeout by JVM:" >> tempWASf".summary";
			for(eTj in arrTtoByJvm){
				print eTj":"arrTtoByJvm[eTj] >> tempWASf".summary";
				ttlTto+=arrTtoByJvm[eTj];
			}
			print "" >> tempWASf".summary";
			print "total Transaction timeout on all JVMs:"ttlTto >> tempWASf".summary";
			if(rptType == "daily"){
				print $2,ttlTto >> rptTranTimeOutHstFile;
			}
		}
		
	}' $tempWASf.tto
	
fi

if [[ -e $tempWASf.cpustarv ]]; then
	awk -vtempWASf=$tempWASf 'BEGIN {
		FS="|";
		print "" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "===== CPU Starvation Warnings =====" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "" >> tempWASf".summary";
		wHdFmt="%-15s\t%-10s\t%-12s\t%-3s\t%5s\n";
		wBdFmt="%-15s\t%-10s\t%-12s\t%-3s\t%5.3f\n";
		printf wHdFmt,"was","date","time","tz","dly" >> tempWASf".summary";
	}
	{
		printf wBdFmt,$1,$2,$3,$4,$5 >> tempWASf".summary";		
	}' $tempWASf.cpustarv
fi

if [[ -e $tempWASf.cpu.summary ]]; then
	#ecpus,arrCPUStarvCnt[ecpus],arrCPUStarvDly[ecpus]
	sort -t'|' -k2nr $tempWASf.cpu.summary | awk -vtempWASf=$tempWASf 'BEGIN {
		FS="|";
		print "" >> tempWASf".summary";
		print "Summary of Scheduling delays:" >> tempWASf".summary";
		print "" >> tempWASf".summary";
		wHdFmt="%-15s\t%-3s\t%-5s\n";
		wBdFmt="%-15s\t%-3s\t%5.3f\n";
		printf wHdFmt,"was","cnt","tdly" >> tempWASf".summary";		
	}
	{
		printf wBdFmt,$1,$2,$3 >> tempWASf".summary";		
	}'
fi

_fFltrSz="0";
if [[ -e $tempWASf.filter ]]; then
	_fFltrSz=$(ls -s $tempWASf.filter | cut -d' ' -f1);
	if [[ $_fFltrSz -gt 0 ]]; then
		awk -vtempWASf=$tempWASf -valrtF=$rptAlertFile -vrptWasFilErrFile=$rptWasFilErrFile 'BEGIN {
			FS=OFS=" ";
			print "" >> tempWASf".summary";
			print "=====================================================" >> tempWASf".summary";
			print "===== Critical or Filtere Error Summary =====" >> tempWASf".summary";
			print "===== For detail, review file: "rptWasFilErrFile" =====" >> tempWASf".summary";
			print "=====================================================" >> tempWASf".summary";
			print "" >> tempWASf".summary";
			weJHfmt="%-15s\t%7s\t%-70s\n";
			weJBfmt="%-15s\t%7d\t%-70s\n";
			printf weJHfmt,"was","cnt","msg" >> tempWASf".summary";
			ttlCErr=0;
		}
		{
			_msg=substr($0,index($0,$11));
			if(_msg ~ "Error.*Getting.*Folder")
				_msg="Error Getting Folder. See stacktrace for details. com.xythos.security.api.TransactionLimitExceededException";
			arrCErr[$1"|"_msg]++;
			ttlCErr++;
		} END {
			for(eCErr in arrCErr){
				split(eCErr,eCETok,"|");
				printf weJBfmt,eCETok[1],arrCErr[eCErr],eCETok[2] >> tempWASf".summary";
				print "Found in "eCETok[1]" total "arrCErr[eCErr]" critical or filtered error: "eCETok[2] >> alrtF 
			}
			print "Total critical or filtered error for all servers:"ttlCErr >> tempWASf".summary";
		}' $tempWASf.filter
	fi
fi	

if [[ -e $tempWASf.errCntBySrv ]]; then
	sort -t'|' -k1,1 -k2,2 $tempWASf.errCntBySrv | awk -vtempWASf=$tempWASf 'BEGIN {
		FS=OFS="|";
		print "" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "===== Summary of Error and Warning count by Server =====" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "" >> tempWASf".summary";
		weJHfmt="%-15s\t%-3s\t%6s\n";
		weJBfmt="%-15s\t%-3s\t%6d\n";
		printf weJHfmt,"was","evt","cnt" >> tempWASf".summary";
		ttlErr=0;
	}
	{
		printf weJBfmt,$1,$2,$3 >> tempWASf".summary";
		ttlErr+=$3;
	} END {
		print "Total for all servers:"ttlErr >> tempWASf".summary";
	}'
fi 

if [[ -e $tempWASf.errCntByFncCmp ]]; then
	cat $tempWASf.errCntByFncCmp | egrep '(E\||F\|)' | sort -t'|' -k3nr | \
	awk -vtempWASf=$tempWASf -vrptWasErrSumByErrCmpFile=$rptWasErrSumByErrCmpFile 'BEGIN {
		FS="|";
		print "" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "===== Summary of (Top 10 by total count) ERROR and FATAL events by component =====" >> tempWASf".summary";
		print "===== Review file: "rptWasErrSumByErrCmpFile" for all Errors and Fatal events =====" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "" >> tempWASf".summary";
		weJHfmt="%-25s\t%-3s\t%6s\n";
		weJBfmt="%-25s\t%-3s\t%6d\n";
		printf weJHfmt,"cmp","evt","cnt" >> tempWASf".summary";
		printf weJHfmt,"cmp","evt","cnt" > tempWASf".ErrSumByErrCmp";
	}
	{
		if(NR <= 10){
			printf weJBfmt,$2,$1,$3 >> tempWASf".summary";
		}
		printf weJBfmt,$2,$1,$3 >> tempWASf".ErrSumByErrCmp";
		
	}'
fi

if [[ -e $tempWASf.errCntByFncCmp ]]; then
	cat $tempWASf.errCntByFncCmp | egrep '(W\|)' | sort -t'|' -k3nr | \
	awk -vtempWASf=$tempWASf -vrptWasWarnSumByWarnCmpFile=$rptWasWarnSumByWarnCmpFile 'BEGIN {
		FS="|";
		print "" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "===== Summary of (Top 10 by total count) WARN events by component =====" >> tempWASf".summary";
		print "===== Review file: "rptWasWarnSumByWarnCmpFile" for all Errors and Fatal events =====" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "" >> tempWASf".summary";
		weJHfmt="%-25s\t%-3s\t%6s\n";
		weJBfmt="%-25s\t%-3s\t%6d\n";
		printf weJHfmt,"cmp","evt","cnt" >> tempWASf".summary";
		printf weJHfmt,"cmp","evt","cnt" > tempWASf".WarnSumByWarnCmp";
	}
	{
		if(NR <= 10){
			printf weJBfmt,$2,$1,$3 >> tempWASf".summary";
		}
		printf weJBfmt,$2,$1,$3 >> tempWASf".WarnSumByWarnCmp";
		
	}'
fi

if [[ -e $tempWASf.errCntByCmp ]]; then
	cat $tempWASf.errCntByCmp | egrep '(E\||F\|)' | sort -t'|' -k3nr | \
		awk -vtempWASf=$tempWASf -vrptWasErrSumByErrClsFile=$rptWasErrSumByErrClsFile 'BEGIN {
		FS="|";
		print "" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "===== Summary of Top 10 by total count) Error and Fatal events by Error class =====" >> tempWASf".summary";
		print "===== Review file: "rptWasErrSumByErrClsFile" for all Error and Fatal events by Error class =====" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "" >> tempWASf".summary";
		weJHfmt="%-3s\t%6s\t%-50s\n";
		weJBfmt="%-3s\t%6d\t%-50s\n";
		printf weJHfmt,"evt","cnt","cmp" >> tempWASf".summary";
		printf weJHfmt,"evt","cnt","cmp" > tempWASf".errorByErrCls";
	}
	{
		if(NR <=10){
			printf weJBfmt,$1,$3,$2 >> tempWASf".summary";
		}
		printf weJBfmt,$1,$3,$2 >> tempWASf".errorByErrCls";
	}'
fi

if [[ -e $tempWASf.errCntByCmp ]]; then
	cat $tempWASf.errCntByCmp | egrep '(W\|)' | sort -t'|' -k3nr | \
		awk -vtempWASf=$tempWASf -vrptWasWarnSumByWarnClsFile=$rptWasWarnSumByWarnClsFile 'BEGIN {
		FS="|";
		print "" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "===== Summary of Top 10 (by total count) WARN events by WARN class =====" >> tempWASf".summary";
		print "===== Review file: "rptWasWarnSumByWarnClsFile" for all WARN events by WARN class =====" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "" >> tempWASf".summary";
		weJHfmt="%-3s\t%6s\t%-50s\n";
		weJBfmt="%-3s\t%6d\t%-50s\n";
		printf weJHfmt,"evt","cnt","cmp" >> tempWASf".summary";
		printf weJHfmt,"evt","cnt","cmp" > tempWASf".warnByWarnCls";
	}
	{
		if(NR <=10){
			printf weJBfmt,$1,$3,$2 >> tempWASf".summary";
		}
		printf weJBfmt,$1,$3,$2 >> tempWASf".warnByWarnCls";
	}'
fi

if [[ -e $tempWASf.errCntByExp ]]; then
	cat $tempWASf.errCntByExp | egrep '(\|E\||\|F\|)' | sort -t'|' -k3nr | \
		awk -vtempWASf=$tempWASf -vrptWasErrSumByExpFile=$rptWasErrSumByExpFile 'BEGIN {
		FS="|";
		print "" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "===== Summary of Top 10 (by total count) Error and Fatal events by Exception =====" >> tempWASf".summary";
		print "===== Review file: "rptWasErrSumByExpFile" for all Error and Fatal events by Exception =====" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "" >> tempWASf".summary";
		weJHfmt="%-25s\t%-3s\t%6s\n";
		weJBfmt="%-25s\t%-3s\t%6d\n";
		printf weJHfmt,"exp","evt","cnt" >> tempWASf".summary";
		printf weJHfmt,"exp","evt","cnt" > tempWASf".errByExp";
	}
	{
		if(NR <= 10){
			printf weJBfmt,$1,$2,$3 >> tempWASf".summary";
		}
		printf weJBfmt,$1,$2,$3 >> tempWASf".errByExp";
	}'
fi

if [[ -e $tempWASf.errCntByExp ]]; then
	cat $tempWASf.errCntByExp | egrep '(\|W\|)' | sort -t'|' -k3nr | \
		awk -vtempWASf=$tempWASf -vrptWasWarnSumByExpFile=$rptWasWarnSumByExpFile 'BEGIN {
		FS="|";
		print "" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "===== Summary of Top 10 (by total count) WARN events by Exception =====" >> tempWASf".summary";
		print "===== Review file: "rptWasWarnSumByExpFile" for all WARN events by Exception =====" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "" >> tempWASf".summary";
		weJHfmt="%-25s\t%-3s\t%6s\n";
		weJBfmt="%-25s\t%-3s\t%6d\n";
		printf weJHfmt,"exp","evt","cnt" >> tempWASf".summary";
		printf weJHfmt,"exp","evt","cnt" > tempWASf".warnByExp";
	}
	{
		if(NR <= 10){
			printf weJBfmt,$1,$2,$3 >> tempWASf".summary";
		}
		printf weJBfmt,$1,$2,$3 >> tempWASf".warnByExp";
	}'
fi

if [[ -e $tempWASf.errCntByMsg ]]; then
	cat $tempWASf.errCntByMsg | egrep '(\|E\||\|F\|)' | sort -t'|' -k1nr | \
		awk -vtempWASf=$tempWASf -vrptWasErrSumByMsgFile=$rptWasErrSumByMsgFile 'BEGIN {
		FS="|";
		print "" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "===== Summary of Top 10 (by total count) ERROR and FATAL events by Message =====" >> tempWASf".summary";
		print "===== Review file: "rptWasErrSumByMsgFile" for all ERROR and FATAL events by Message =====" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "" >> tempWASf".summary";
		weJHfmt="%6s\t%-3s\t%-25s\n";
		weJBfmt="%6d\t%-3s\t%-25s\n";
		printf weJHfmt,"cnt","evt","msg" >> tempWASf".summary";
		printf weJHfmt,"cnt","evt","msg" > tempWASf".byErrMsg";
	}
	{
		if(NR <=10){
			printf weJBfmt,$1,$2,$3 >> tempWASf".summary";
		}
		printf weJBfmt,$1,$2,$3 >> tempWASf".byErrMsg";
	}'
fi

if [[ -e $tempWASf.errCntByMsg ]]; then
	cat $tempWASf.errCntByMsg | egrep '(\|W\|)' | sort -t'|' -k1nr | \
		awk -vtempWASf=$tempWASf -vrptWasWarnSumByMsgFile=$rptWasWarnSumByMsgFile 'BEGIN {
		FS="|";
		print "" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "===== Summary of Top 10 (by total count) WARN events by Message =====" >> tempWASf".summary";
		print "===== Review file: "rptWasWarnSumByMsgFile" for all WARN events by Message =====" >> tempWASf".summary";
		print "=====================================================" >> tempWASf".summary";
		print "" >> tempWASf".summary";
		weJHfmt="%6s\t%-3s\t%-25s\n";
		weJBfmt="%6d\t%-3s\t%-25s\n";
		printf weJHfmt,"cnt","evt","msg" >> tempWASf".summary";
		printf weJHfmt,"cnt","evt","msg" > tempWASf".byWarnMsg";
	}
	{
		if(NR <=10){
			printf weJBfmt,$1,$2,$3 >> tempWASf".summary";
		}
		printf weJBfmt,$1,$2,$3 >> tempWASf".byWarnMsg";
	}'
fi



if [[ -e $tempWASf.was.error.all ]]; then
	mv $tempWASf.was.error.all $rptWasErrFile
fi
if [[ -e $tempWASf.summary ]]; then
	mv $tempWASf.summary $rptWasSummaryFile
fi
if [[ $_fFltrSz -gt 0 ]]; then
	mv $tempWASf.filter $rptWasFilErrFile
fi

if [[ -e $tempWASf.ErrSumByErrCmp ]]; then
	mv $tempWASf.ErrSumByErrCmp $rptWasErrSumByErrCmpFile
fi
if [[ -e $tempWASf.errorByErrCls ]]; then
	mv $tempWASf.errorByErrCls $rptWasErrSumByErrClsFile
fi
if [[ -e $tempWASf.errByExp ]]; then
	mv $tempWASf.errByExp $rptWasErrSumByExpFile
fi
if [[ -e $tempWASf.byErrMsg ]]; then
	mv $tempWASf.byErrMsg $rptWasErrSumByMsgFile
fi
if [[ -e $tempWASf.WarnSumByWarnCmp ]]; then
	mv $tempWASf.WarnSumByWarnCmp $rptWasWarnSumByWarnCmpFile
fi
if [[ -e $tempWASf.warnByWarnCls ]]; then
	mv $tempWASf.warnByWarnCls $rptWasWarnSumByWarnClsFile
fi
if [[ -e $tempWASf.warnByExp ]]; then
	mv $tempWASf.warnByExp $rptWasWarnSumByExpFile
fi
if [[ -e $tempWASf.byWarnMsg ]]; then
	mv $tempWASf.byWarnMsg $rptWasWarnSumByMsgFile
fi

echo "========== End of WAS Alert Section ==========" >> $rptAlertFile
trap 'rm -f $tempWASf*' INT TERM EXIT
echo "$0 completed at: "$(date +"%Y-%m-%dT%H:%M:%S")" with total execution time: "$SECONDS" sec" 2>&1 | tee -a $parserExeLog
echo "==================================================================" 2>&1 | tee -a $parserExeLog
