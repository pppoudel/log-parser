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
#	Parses Apache/IBM HTTP Server error_log. 
# Produces Alert.log, summary reports and historical reports.
# Execute as:
# ./webErrorLogParser.sh <options>
# Execute below command to see all the available options:
# ./webErrorLogParser.sh

# Include usage
source ./usage.sh
echo "==================================================================" 2>&1 | tee -a $parserExeLog
echo "$0 started at: "$(date +"%Y-%m-%dT%H:%M:%S") 2>&1 | tee -a $parserExeLog
echo "Processing logs with the following input command line:" 2>&1 | tee -a $parserExeLog
echo "$cmdln" 2>&1 | tee -a $parserExeLog;

#--------- Input files ---------------#
fTh=./thresholdValues.csv
#--------- Report/Output files -------#
rptAlertFile="$rptDir/00_Alert.txt"
rptSummaryFile="$rptDir/03_WebErrorLogSummaryRpt.txt";
rptMpmStatsFile="$rptDir/WebErrorLogMpmStatsRpt_all.csv"
rptErrFile="$rptDir/WebErrorLogRpt_all.csv"

#--------- History Report/Output files -------#
# These are historical reports. Each run will append record in existing report file.
# If historical file does not exist, create and add heading.

rptRecycleHstFile="$pDir/RecycleHistoryRpt_all.csv";
if [[ ! -e $rptRecycleHstFile && $rptType == "daily" ]]; then
	echo "#srv: server" > $rptRecycleHstFile;
	echo "date|srv" >> $rptRecycleHstFile;
fi
rptMpmStHstFile="$pDir/MPMStatsHistoryRpt.csv";
if [[ ! -e $rptMpmStHstFile && $rptType == "daily" ]]; then
	echo "#hr		: Hour " > $rptMpmStHstFile
	echo "#date	: Date " >> $rptMpmStHstFile
	echo "#time	: Time " >> $rptMpmStHstFile
	echo "#rdy	: Ready thread(s)" >> $rptMpmStHstFile
	echo "#bsy	: Busy threads(s)" >> $rptMpmStHstFile
	echo "#rd		: Read - number of threads currently reading request from user" >> $rptMpmStHstFile
	echo "#wr		: Write - number of threads currently writing or communicating to App Server or back-end" >> $rptMpmStHstFile
	echo "#ka		: Keep Alive - number of threads holding keep alive session	" >> $rptMpmStHstFile
	echo "#log	: Log - number of threads busy in logging" >> $rptMpmStHstFile
	echo "#dns	: DNS - number of threads busy in DNS related activities" >> $rptMpmStHstFile
	echo "#cls	: CLS - number of threads busy in house cleaning related activities" >> $rptMpmStHstFile
	echo "#mwas	: Number of threads busy with mod_was_ap22_http.c" >> $rptMpmStHstFile
	echo "#mwgt	: Number of threads busy with apache2entry_web_gate.cpp" >> $rptMpmStHstFile
	echo "#cnt	: (Any) Count like jSession count, User count etc." >> $rptMpmStHstFile
	echo "webserver|date|time|hr|rdy|bsy|rd|wr|ka|log|dns|cls|mwas|mwgt" >> $rptMpmStHstFile
fi

#--------- Parser log -------#
parserExeLog=$TMP/parser.log

if [[ $rptType == "ondemand" && "$currDate" == "$recDate" ]]
   then
	logFileName="error_log$"
   else
	logFileName="error_log.$rec0MM$rec0DD$recYY"	
fi

echo "" >> $parserExeLog

logFiles=`find $rootcontext -name "error_log*" -type f | grep "$logFileName"`
lgFound=$?;
if [ "${lgFound}" -ne "0" ]; then
	echo "No log file found to process. exiting ...";
	exit 1;
fi
errSumF=`mktemp`

echo "========== Start of Web Error Report Alert Section ==========" >> $rptAlertFile 
for z in $logFiles
do
	echo "parsing file: $z" >> $parserExeLog
	pName=`dirname $z | rev | awk -F \/ '{print $1}' | rev`
	cat $z | egrep '(\[.*'$recLM'.*'$rec0DD'.*'$recYYYY'\])' | sed -e "s/^/$pName\] /g"
done | \
awk -vfTh=$fTh -verrSumF=$errSumF -valrtF=$rptAlertFile -vrecDate=$recDate -vrecMM=$recMM \
   -vrecYY=$recYY -vrecDD=$recDD -vrptRecycleHstFile=$rptRecycleHstFile \
	'BEGIN{FS="] ";
		mpmHdLst="rdy,bsy,rd,wr,ka,log,dns,cls,mod_was_ap22_http.c,apache2entry_web_gate.cpp";
		split(mpmHdLst,arrMpmHdLst,",");		
		# Get the threshold values
		while((getline thln < fTh) > 0){
			split(thln,arrThln,"|");
			pattern="^http.*";
			if(arrThln[3] ~ pattern){
				arrTh[arrThln[1]]=arrThln[2];
				arrTh[arrThln[3]"."arrThln[1]]=arrThln[2];								
			}
		}
		close(thln);
		close(fTh);
		
		print "=====================================================" > errSumF".summary";
		print "===== Http Error log analysis report =====" >> errSumF".summary";
		print "===== based on error logs dated: " recDate"  =====" >> errSumF".summary";
		print "=====================================================" >> errSumF".summary";
		print "" >> errSumF".summary";		
		print "===== Summary table contains short heading title. See below for their description =====" >> errSumF".summary";
		pSFmt="%-5s\t%-70s\n";
		printf pSFmt,"hr",": Hour " >> errSumF".summary";
		printf pSFmt,"date",": Date " >> errSumF".summary";
		printf pSFmt,"time",": Time " >> errSumF".summary";
		
		printf pSFmt,"rdy",": Ready thread(s)" >> errSumF".summary";
		printf pSFmt,"bsy",": Busy threads(s)" >> errSumF".summary";
		printf pSFmt,"rd",": Read - number of threads currently reading request from user" >> errSumF".summary";
		printf pSFmt,"wr",": Write - number of threads currently writing or communicating to App Server or back-end" >> errSumF".summary";
		printf pSFmt,"ka",": Keep Alive - number of threads holding keep alive session" >> errSumF".summary";	
		printf pSFmt,"log",": Log - number of threads busy in logging" >> errSumF".summary";
		printf pSFmt,"dns",": DNS - number of threads busy in DNS related activities" >> errSumF".summary";
		printf pSFmt,"cls",": CLS - number of threads busy in house cleaning related activities" >> errSumF".summary";
		printf pSFmt,"mwas",": Number of threads busy with mod_was_ap22_http.c" >> errSumF".summary";
		printf pSFmt,"mwgt",": Number of threads busy with apache2entry_web_gate.cpp" >> errSumF".summary";
		printf pSFmt,"was",": WebSphere Application Server or App Server" >> errSumF".summary";
		printf pSFmt,"ws",": Web Server like Apache or IBM HTTP Server (IHS) " >> errSumF".summary";
		printf pSFmt,"req",": HTTP Request like GET, POST etc." >> errSumF".summary";
		printf pSFmt,"rsp",": HTTP Response code like 200, 400 etc." >> errSumF".summary";
		printf pSFmt,"err",": Error message" >> errSumF".summary";
		printf pSFmt,"dtl",": Detail - detail message" >> errSumF".summary";
		printf pSFmt,"ref",": Http referrer" >> errSumF".summary"; 
		printf pSFmt,"cnt",": (Any) Count like jSession count, User count etc. " >> errSumF".summary";
		printf pSFmt,"url",": URL" >> errSumF".summary";
		print "=====================================================" >> errSumF".summary";
		
		}
		{
			#since date section is used for all situation. let is parse here:
			pName=$1;
			split($2,dt," ");
			_date=dt[2]"-"dt[3]"-"dt[5];
			_tm=dt[4];
			split(dt[4],hr,":");
			_hr=hr[1];
			switch($0){
				case /mpmstats: rdy/:
					#srvwebxxxxx0x0] [Fri Jun 05 14:12:27 2015] [notice] mpmstats: rdy 49 bsy 51 rd 12 wr 31 ka 8 log 0 dns 0 cls 0
					split($4,st1stLn,":");
					#print "==== st1stLn: " st1stLn[2];
					split(st1stLn[2],stats," ");
					#rdy:key=stats[1];val=stats[2]
					#bsy:key=stats[3];val=stats[4]
					#rd: key=stats[5];val=stats[6]
					#wr: key=stats[7];val=stats[8]
					#ka: key=stats[9];val=stats[10]
					#log:key=stats[11];val=stats[12]
					#dns:key=stats[13];val=stats[14]
					#cls:key=stats[15];val=stats[16]
					val=_hr"|"stats[2]"|"stats[4]"|"stats[6]"|"stats[8]"|"stats[10]"|"stats[12]"|"stats[14]"|"stats[16];
					#print "===val: "val;
					arrGStats[pName"|"_date"|"_tm]=val;	
					#put some alert here
					#httpMpmStBsyCountTh|100|IMMS.http.mpmstat|IMMS MPM Stats Busy count threshold.
					#Busy alert
					thKeyBsyCnt="http.mpmstat.httpMpmStBsyCountTh";
					thValBsyCnt=arrTh[thKeyBsyCnt];
					thKeyRdCnt="http.mpmstat.httpMpmStRdCountTh";
					thValRdCnt=arrTh[thKeyRdCnt];
					thKeyWrCnt="http.mpmstat.httpMpmStWrCountTh";
					thValWrCnt=arrTh[thKeyWrCnt];
					
					if(thValBsyCnt !="" && stats[4] > thValBsyCnt) {
						print stats[4]" : number of "stats[3]" thread for "pName" at "_date":"_tm" exceeds threshold value of: " thValBsyCnt". Investigate further and make sure nothing extraordinary happening" >> alrtF;
					}
					if(thValRdCnt !="" && stats[6] > thValRdCnt) {
						print stats[6]" : number of "stats[5]" thread for "pName" at "_date":"_tm" exceeds threshold value of: " thValRdCnt". Investigate further and make sure nothing extraordinary happening" >> alrtF;
					}
					if(thKeyWrCnt !="" && stats[8] > thKeyWrCnt) {
						print stats[8]" : number of "stats[7]" thread for "pName" at "_date":"_tm" exceeds threshold value of: " thKeyWrCnt". Investigate further. There is possibility of hung threads on App Server(s)" >> alrtF;
					}
				break;
				case /mpmstats: bsy/:
					#srvwebxxxxx0x0] [Fri Jun 05 14:12:27 2015] [notice] mpmstats: bsy: 5 in mod_was_ap22_http.c, 26 in apache2entry_web_gate.cpp
					#5 in mod_was_ap22_http.c, 26 in apache2entry_web_gate.cpp
					split($4,st2ndLn,":");
					split(st2ndLn[3],tmStats,",");
					if(length(tmStats) < 2){
						# meaning only one plugin stats reported.
						split(tmStats[1],stats1," ");
						plgNm1=stats1[3];
						plgVal1=stats1[1];
						plgNm2="";
						plgVal2="";
						
					} else {
						split(tmStats[1],stats1," ");
						plgNm1=stats1[3];
						plgVal1=stats1[1];
						split(tmStats[2],stats2," ");
						plgNm2=stats2[3];
						plgVal2=stats2[1];
					}
					#WebSphere Plugin busy thread, if not reported, means 0
					wsBsy=0;
					#Oracle WebGate Plugin busy thread, if not reported, means 0
					wbgBsy=0;
					if(plgNm1 == arrMpmHdLst[9]){
						wsBsy=plgVal1;
					}
					if(plgNm1 == arrMpmHdLst[10]){
						wbgBsy=plgVal1;
					}
					if(plgNm2 == arrMpmHdLst[9]){
						wsBsy=plgVal2;
					}
					if(plgNm2 == arrMpmHdLst[10]){
						wbgBsy=plgVal2;
					}
										
					val=wsBsy"|"wbgBsy;
					#print" ===busy val:"val;
					arrPStats[pName"|"_date"|"_tm]=val;
					
					thKeyPlgCnt="http.mpmstat.httpMpmStPlgCountTh";
					thValPlgCnt=arrTh[thKeyPlgCnt];
					if(thValPlgCnt !="" && wsBsy > thValPlgCnt) {
						print wsBsy" : number of "arrMpmHdLst[9]" thread for "pName" at "_date":"_tm" exceeds threshold value of: " thValPlgCnt". Investigate further. There is possibility of hung threads on App Server(s)" >> alrtF;
					}
					if(thValPlgCnt !="" && wbgBsy > thValPlgCnt) {
						print wbgBsy" : number of "arrMpmHdLst[10]" thread for "pName" at "_date":"_tm" exceeds threshold value of: " thValPlgCnt". Investigate further. There is possibility that Access Manager (WebGate) may not responding well." >> alrtF;
					}
				break;
				case /mpmstats: approaching MaxClients/:
					#srvwebxxxxx0x0] [Fri Sep 25 14:05:20 2015] [notice] mpmstats: approaching MaxClients (545/600)
					OFS=" ";
					print "["$0 >> alrtF;
				break;
				case /IBM_HTTP_Server.* configured -- resuming normal operations/:
					print pName " recycled at: "recMM"/"recDD"/"recYY,dt[4] >> alrtF;
					if(rptType == "daily"){
						print recMM"/"recDD"/"recYY,dt[4],pName >> rptRecycleHstFile;
					}
				break;
				default:
					#process other error logs
					OFS="|";
					split($4,clnt," ");
					split($5,det,",");
					split(det[1],flt,":");
					split(det[2],ref,": ");
					evtType=substr($3,2);
					switch(evtType){
						case "error":
							if($0 ~ /MaxClients/){
								OFS=" ";
								print "["$0 >> alrtF;
							} else {
								print pName,_date,_tm,_hr,evtType, clnt[2], flt[1],substr(flt[2],2),ref[2] >> errSumF".all";
							}
						break;
						case /(crit|alert)/:
							print pName,_date,_tm,_hr,evtType, clnt[2], flt[1],substr(flt[2],2),ref[2] >> alrtF
						break;						
						default:
						break;
					}					
				break;				
			}
		} END {
			if(length(arrGStats) > 0){
				for(eachGSts in arrGStats){
					#get plugin stats
					pStat=arrPStats[eachGSts];
					#mpmHdLst="rdy,bsy,rd,wr,ka,log,dns,cls,mod_was_ap22_http.c,apache2entry_web_gate.cpp";
					#split(mpmHdLst,arrMpmHdLst,",");					
					print eachGSts,arrGStats[eachGSts],pStat >> errSumF".mpmstats";					
				}
			}
			
		}'


if [[ -e $errSumF.all ]]; then
	cat $errSumF.all | awk -vfTh=$fTh -valrtF=$rptAlertFile -verrSumF=$errSumF \
		'BEGIN{
			FS=OFS="|";
			errCntTh=100;
			errThMsg="Total error count exceeds threshold of "errCntTh
			# Write heading
			print "Server|Date|Time|Hour|evtType|client|Err|ErrDet|Referrer" > errSumF".all.withhead"
			# Get the threshold values
			while((getline thln < fTh) > 0){
				split(thln,arrThln,"|");
				pattern="^http.err";
				if(arrThln[3] ~ pattern){
					arrTh[arrThln[1]]=arrThln[2];
					arrTh[arrThln[3]"."arrThln[1]]=arrThln[2];								
				}
			}
			close(thln);
			close(fTh);
			thKeyErrCntBySrv="http.err.httpErrorCountTh";
			thValErrCntBySrv=arrTh[thKeyErrCntBySrv];
			#print "key-thKeyErrCntBySrv:"thKeyErrCntBySrv"; value:"thValErrCntBySrv;
			} {
			if($5 == "error"){
				split($9,arrRef,"?");
				ref=arrRef[1];
				errCntBySrv[$1]++;
				errCntByErrDet[$7"|"$8]++;
				errCntByRef[ref"|"$7" : "$8]++;
			}
			print $0 >> errSumF".all.withhead";
			
		}
		END {
			# print to alert file if total error count greater than certain threshold. TBD
			#print "error count by server & hour:";
			for (esh in errCntBySrv) {
				print esh, errCntBySrv[esh] >> errSumF".errCntBySrv";
				# print to alert file if any value of errCntBySrv[esh] is greater than threshold. TBD
				if(thValErrCntBySrv != "" && errCntBySrv[esh] > thValErrCntBySrv){
					print errCntBySrv[esh]" : number of http errors for "esh" exceeds threshold value of: " thValErrCntBySrv". Investigate further." >> alrtF;
				}
			}
			#print "error count by error det :";
			for (erd in errCntByErrDet) {
				print erd, errCntByErrDet[erd] >> errSumF".errCntByErrDet";
				# print to alert file if any value of errCntByErrDet[erd] is greater than threshold. TBD
			}
			#print "error count by Referrer :";
			for (er in errCntByRef) {
				print er, errCntByRef[er] >> errSumF".errCntByRef";
				# print to alert file if any value of errCntByRef[er] is greater than threshold. TBD
			}
			
		}'
fi
echo "========== End of Web Error Report Alert Section ==========" >> $rptAlertFile

if [[ -e $errSumF.mpmstats ]]; then
	sort -t'|' -k1,1 -k4n,4n -k3,3  $errSumF.mpmstats | \
	awk -verrSumF=$errSumF -vrptMpmStHstFile=$rptMpmStHstFile -vrptType=$rptType 'BEGIN {
		FS="|";
		hHdFmt="%-15s\t%-11s\t%-8s\t%4s\t%4s\t%4s\t%4s\t%4s\t%4s\t%4s\t%4s\t%4s\t%4s\t%4s\n";
		hBdFmt="%-15s\t%-11s\t%-8s\t%4s\t%4d\t%4d\t%4d\t%4d\t%4d\t%4d\t%4d\t%4d\t%4d\t%4d\n";
		printf hHdFmt,"ws","date","time","hr","rdy","bsy","rd","wr","ka","log","dns","cls","mwas","mwgt" > errSumF".mpmstats.sorted";		
	}
	{
		printf hBdFmt,$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14 >> errSumF".mpmstats.sorted";
		if(rptType == "daily"){
			if(arrBsyMx[$1] != ""){
				#print " Exist record: "$1 $3;
				if($6 > arrBsyMx[$1]){
					arrBsyMx[$1]=$6
					arrMpmHst[$1]=$0;
				}
			} else {
				#print "Does not exist. Adding: "$1 $3 $6;
				arrBsyMx[$1]=$6;
				arrMpmHst[$1]=$0;
			}
		}
	} END {
		if(length(arrMpmHst) > 0){
			for(eMpmSt in arrMpmHst){
				print arrMpmHst[eMpmSt] >> rptMpmStHstFile;
			}
		}
	}'
	mv $errSumF.mpmstats.sorted $rptMpmStatsFile
	
fi

if [[ -e $errSumF.all.withhead ]]; then
	mv $errSumF.all.withhead $rptErrFile
fi

if [[ -e $errSumF.errCntBySrv ]]; then
	sort -t'|' -k2nr $errSumF.errCntBySrv | \
	awk -verrSumF=$errSumF 'BEGIN {
		FS=OFS="|";
		hHdFmt="%-15s\t%5s\n";
		hBdFmt="%-15s\t%5d\n";
		print "" >> errSumF".summary";
		print "=====================================================" >> errSumF".summary";
		print "===== Http Error Count by Web Server =====" >> errSumF".summary";
		print "=====================================================" >> errSumF".summary";
		print "" >> errSumF".summary";
		printf hHdFmt,"ws","cnt" >> errSumF".summary";
		ttlErrCnt=0;
	}
	{
		printf hBdFmt,$1,$2 >> errSumF".summary";
		ttlErrCnt+=$2;
	} END {
		print "Total http error count: "ttlErrCnt >> errSumF".summary";
	}'
fi

if [[ -e $errSumF.errCntByErrDet ]]; then
	cat $errSumF.errCntByErrDet | sort -t'|' -k3nr | \
	awk -verrSumF=$errSumF 'BEGIN {
		FS=OFS="|";
		hHdFmt="%-5s\t%-50s\t%-60s\n";
		hBdFmt="%5d\t%-50s\t%-60s\n";
		print "" >> errSumF".summary";
		print "=====================================================" >> errSumF".summary";
		print "===== Http Error Count by Http Error Detail =====" >> errSumF".summary";
		print "=====================================================" >> errSumF".summary";
		print "" >> errSumF".summary";
		printf hHdFmt,"cnt","err","dtl" >> errSumF".summary";		
	}
	{
		printf hBdFmt,$3,$1,$2 >> errSumF".summary";		
	}'
fi

if [[ -e $errSumF.errCntByRef ]]; then
	sort -t'|' -k3nr $errSumF.errCntByRef | \
	awk -verrSumF=$errSumF 'BEGIN {
		FS=OFS="|";
		hHdFmt="%-5s\t%-145s\t%-150s\n";
		hBdFmt="%5d\t%-145s\t%-150s\n";
		print "" >> errSumF".summary";
		print "=====================================================" >> errSumF".summary";
		print "===== Http Error Count by Http Referrer =====" >> errSumF".summary";
		print "=====================================================" >> errSumF".summary";
		print "" >> errSumF".summary";
		printf hHdFmt,"cnt","ref","dtl" >> errSumF".summary";		
	}
	{
		printf hBdFmt,$3,$1,$2 >> errSumF".summary";		
	}'	
fi

if [[ -e $errSumF.summary ]]; then
	mv $errSumF.summary $rptSummaryFile
fi
 
trap 'rm -f $errSumF*' INT EXIT TERM

echo "$0 completed at: "$(date +"%Y-%m-%dT%H:%M:%S")" with total execution time: "$SECONDS" sec" 2>&1 | tee -a $parserExeLog
echo "==================================================================" 2>&1 | tee -a $parserExeLog