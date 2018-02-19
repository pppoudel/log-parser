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
#	Parses WAS native_stdout.log. 
# Produces Alert.log, Statistical reports, Error reports and historical reports.
# If you have logs from multiple Application servers, put corresponding logs under directory named using server name. For example,
# Let's say, you have Application servers 'appSrv01, appSrv02, appSrv03 ...etc), then put logs from each App Server under directory like:
# /tmp/appSrv01/
#     native_stdout.log
# /tmp/appSrv02/
#     native_stdout.log
# /tmp/appSrv03/
#    native_stdout.log 		
#
# Execute as:
# ./javaGCStatsParser.sh <options>
# Execute below command to see all the available options:
# ./javaGCStatsParser.sh


source ./usage.sh
echo "==================================================================" 2>&1 | tee -a $parserExeLog
echo "$0 started at: "$(date +"%Y-%m-%dT%H:%M:%S") 2>&1 | tee -a $parserExeLog
echo "Processing logs with the following input command line:" 2>&1 | tee -a $parserExeLog
echo "$cmdln" 2>&1 | tee -a $parserExeLog;

#--------- Input files ---------------#
fTh=./thresholdValues.csv

#--------- Report/Output files -------#
rptAlertFile="$rptDir/00_Alert.txt"
rptGcSumFile="$rptDir/04_GCSummaryRpt.txt"
rptGcFile="$rptDir/GCstatsRpt_all.csv"

#--------- History Report/Output files -------#
rptGcHstAllFile="$pDir/GCHistoryRpt_all.csv"

if [[ ! -e $rptGcHstAllFile && $rptType == "daily" ]]; then
	echo "===== Summary table contains short heading title. See below for their description =====" > $rptGcHstAllFile;
	echo "" >> $rptGcHstAllFile;
	echo "date:  Date " >> $rptGcHstAllFile;		
	echo "time:  Time " >> $rptGcHstAllFile;
	echo "tz:  Time Zone " >> $rptGcHstAllFile;
	echo "jvm:  Java Virtual Machine, may be interchangeably used with was or srv in reports." >> $rptGcHstAllFile;
	echo "artgc:  Average Real Time for Minor GC " >> $rptGcHstAllFile;
	echo "artfgc:  Average Real Time for Full or Major GC " >> $rptGcHstAllFile;
	echo "trtgc:  Total Real Time for Minor GC " >> $rptGcHstAllFile;
	echo "trtfgc:  Total Real Time for Full or Major GC" >> $rptGcHstAllFile;
	echo "rt:  Real Time for GC or Full or Major GC" >> $rptGcHstAllFile;
	echo "trt:  Total Real Time - includes both Minor GC and Major GC" >> $rptGcHstAllFile;
	echo "gccnt:  Total Minor GC count for a given period (date)" >> $rptGcHstAllFile;
	echo "gccntsr:  Total Minor GC count since restart of JVM" >> $rptGcHstAllFile;
	echo "fgccnt:  Total Full or Major GC count for a given period (date)" >> $rptGcHstAllFile;
	echo "fgccntsr:  Total Full or Major GC count since restart of JVM" >> $rptGcHstAllFile;
	echo "tgccnt:  Total All (Minor GC plus Major GC) count for a given period (date) " >> $rptGcHstAllFile;
	echo "tgccntsr:  Total All (Minor GC plus Major GC) count since restart of JVM " >> $rptGcHstAllFile;
	echo "gctp:  Garbage Collection (GC) Type - (Minor)GC or FULLGC " >> $rptGcHstAllFile;
	echo "ygub(K):  Young Generation Used Before GC (K)" >> $rptGcHstAllFile;
	echo "ygua(K):  Young Generation Used After GC (K)" >> $rptGcHstAllFile;
	echo "ygdf(K):  Young Generation Difference Before and After GC" >> $rptGcHstAllFile;
	echo "ygta(K):  Young Generation Total Allocated  After GC" >> $rptGcHstAllFile;
	echo "ygua%:  Young Generation Used Percentage After GC" >> $rptGcHstAllFile;
	echo "ogub(K):  Old Generation Used Before GC (K)" >> $rptGcHstAllFile;
	echo "ogua(K):  Old Generation Used After GC (K)" >> $rptGcHstAllFile;
	echo "ogdf(K):  Old Generation Difference Before and After GC" >> $rptGcHstAllFile;
	echo "ogta(K):  Old Generation Total Allocated  After GC" >> $rptGcHstAllFile;
	echo "ogua%:  Old Generation Used Percentage After GC" >> $rptGcHstAllFile;
	echo "pgub(K):  Perm Generation Used Before GC (K)" >> $rptGcHstAllFile;
	echo "pgua(K):  Perm Generation Used After GC (K)" >> $rptGcHstAllFile;
	echo "pgdf(K):  Perm Generation Difference Before and After GC" >> $rptGcHstAllFile;
	echo "pgta(K):  Perm Generation Total Allocated  After GC" >> $rptGcHstAllFile;
	echo "pgua%:  Perm Generation Used Percentage After GC" >> $rptGcHstAllFile;
	echo "hgub(K):  Heap Used Before GC (K)" >> $rptGcHstAllFile;
	echo "hgua(K):  Heap Used After GC (K)" >> $rptGcHstAllFile;
	echo "hgdf(K):  Heap Difference Before and After GC" >> $rptGcHstAllFile;
	echo "hgta(K):  Heap Total Allocated  After GC" >> $rptGcHstAllFile;
	echo "hgua%:  Heap Used Percentage After GC" >> $rptGcHstAllFile;			
	echo "=====================================================" >> $rptGcHstAllFile;
	echo "jvm|gctp|date|time|tz|hr|ygub(K)|ygua(K)|ygdf(K)|ygta(K)|ygua%|ogub(K)|ogua(K)|ogdf(K)|ogta(K)|ogua%|pgub|pgua|pgdf|pgta|pgua%|hgub(K)|hgua(K)|hgdf(K)|hgta(K)|hgua%|utm|stm|rt|unt|tgccntsr|fgccntsr|tagccntsr" >>$rptGcHstAllFile;
fi

logFiles=`find $rootcontext -type f -name "native_stdout.log"`
if [ "${logFiles}" == "" ]; then
	echo "No log file found. exiting ...";
	exit 1;
fi

echo "========== Start of GC Alert Section ==========" >> $rptAlertFile;		
tempfGC=`mktemp`

for _file in $logFiles
do
	echo "Started parsing file: " $_file 2>&1 | tee -a $parserExeLog
	#pName=`dirname $_file | awk -F"/" '{print $NF}'`
	if [[ $PO == "partial" ]]; then
		#get the line number-9 of matching string.
		#lnToRd=`awk -vrecDate=$recDate '$0 ~ recDate {print NR;exit}' $_file`
		lnToRd=`grep -on -m 1 "$recDate" $_file | cut -d':' -f1`
		if [[ $lnToRd == "" ]]; then
			continue;
		else
			#echo "line number:"$lnToRd
			#awk -vlnToRd=$lnToRd 'NR >= lnToRd {print $0}' $_file
			lnToRd=$(($lnToRd-9))
			tail -n +$lnToRd $_file
		fi
	else
		cat $_file		
	fi
	echo "Completed parsing file: "$_file 2>&1 | tee -a $parserExeLog
done | \
awk -vfTh=$fTh -vrecDate=$recDate -vrptType=$rptType -vrptGcSumFile=$rptGcSumFile -vrptDir=$rptDir \
    -vrptAlertFile=$rptAlertFile -vtempfGC=$tempfGC -vrptGcHstAllFile=$rptGcHstAllFile -vPO=$PO \
	'BEGIN {
		
		FS="[";	
		OFS="|";
		_gcType="GC";
		_xtractOldPermBVals="true";
		_xtractOldPermAVals="false";
		# Get the threshold values
		while((getline thln < fTh) > 0){
			# first line is heading. Ignore
			split(thln,arrThln,"|");
			pattern="^jvm.*";
			if(arrThln[3] ~ pattern){
				#print arrTh[arrThln[1]],arrThln[2]
				#arrTh[arrThln[1]]=arrThln[2];
				arrTh[arrThln[3]"."arrThln[1]]=arrThln[2];
				#print "reading threshold values: " NR, arrThln[1],arrThln[2];				
			}
		}
		close(thln);
		close(fTh);	
		print "JVM","GCType","Date","Time","TZ","Hour","YoungGenUsed-Before(K)","YoungGenUsed-After(K)","YoungGenDiff(K)","YoungGenTotal-After(K)","YongGenUsed-After(%)","OldGenUsed-Before(K)","OldGenUsed-After(K)","OldGenDiff(K)","OldGenTotal-After(K)","OldGenUsed-After(%)","PermGenUsedBefore(K)","PermGenUsed-After(K)","PermGenDiff(K)","PermGenTotal-After(K)","PermGenUsed-After(%)","HeapUsed-Before(K)","HeapUsed-After(K)","HeapDiff(K)","HeapTotal-After(K)","HeapUsedAfter(%)","UserTime","SysTime","RealTime(Sec)","RealTimeUnit","GCNumSinceRestart","FullGCNumSinceRestart","TotalGCsSinceRestart" > tempfGC".vgc.all";
		lstHdFmt="%-15s\t%-4s\t%-10s\t%-12s\t%-5s\t%10s\t%10s\t%10s\t%10s\t%7s\t%10s\t%10s\t%10s\t%10s\t%7s\t%10s\t%10s\t%10s\t%10s\t%7s\t%10s\t%10s\t%10s\t%10s\t%7s\t%5s\t%5s\t%5s\t%5s\n";
		lstBdFmt="%-15s\t%-4s\t%-10s\t%-12s\t%-5s\t%10d\t%10d\t%10d\t%10d\t%7.3f\t%10d\t%10d\t%10d\t%10d\t%7.3f\t%10d\t%10d\t%10d\t%10d\t%7.3f\t%10d\t%10d\t%10d\t%10d\t%7.3f\t%5.3f\t%5d\t%5d\t%5d\n";
		printf lstHdFmt,"jvm","gctp","date","time","tz","ygub(K)","ygua(K)","ygdf(K)","ygta(K)","ygua%","ogub(K)","ogua(K)","ogdf(K)","ogta(K)","ogua%","pgub(K)","pgua(K)","pgdf(K)","pgta(K)","pgua%","hgub(K)","hgua(K)","hgdf(K)","hgta(K)","hgua%","rt(sec)","gccntsr","fgccntsr","tgccntsr" > tempfGC".lstRcd";
	}
	{
		_writeLn="false";
		_gcStr="";
		#print "gc source line: "$0;
		switch($0){
			case /Started.*parsing.*file:.*/:
				split($0,tmpTok,"/");
				pName=tmpTok[length(tmpTok)-1];
				# fake values - work around for partial type
				_oldBGC="NN";
				_prmBGC="NN";
				print $0;
			break;				
			case /\{Heap.*before.*GC.*invocations\=.*/:
				#print "New GC invocation starts. Reseting values ...";
				_xtractOldPermBVals="true";
				#_newGCInvc="true";
				_oldBGC="";
				_oldAGC="";
				_oldTHp="";
				_prmBGC="";
				_prmAGC="";
				_prmTHp="";
				_yngBGC="";
				_yngAGC="";
				_yngTHp="";
				_hpTBGC="";
				_hpTAGC="";
				_THp="";				
			break;
			case /.*ParOldGen.*total.*/:
				if(_xtractOldPermBVals == "true"){
					split($1,parOldTok,",");
					split(parOldTok[2],parOldTok3," ");
					_oldBGC=parOldTok3[2];
					#print "entering to oldperm before ln:"$0" ;_oldBGC:"_oldBGC "; NR:" NR;					
				}
				if(_xtractOldPermAVals == "true"){
					split($1,parOldTok,",");
					split(parOldTok[1],parOldTok2," ");
					split(parOldTok[2],parOldTok3," ");
					_oldTHp=parOldTok2[3];
					_oldAGC=parOldTok3[2];
					
					#print "entering to oldperm after ln:"$0" ;_oldTHp: "_oldTHp" _oldBGC:"_oldBGC" _oldAGC:" _oldAGC "; NR:" NR;
				}
				#print"extracted values _oldTHp: "_oldTHp" _oldBGC:"_oldBGC" _oldAGC:" _oldAGC;
			break;
			case /.*PSPermGen.*total.*/:
				if(_xtractOldPermBVals == "true"){
					split($1,psPmTok,",");
					split(psPmTok[2],psPmTok3," ");
					_prmBGC=psPmTok3[2];					
				}
				if(_xtractOldPermAVals == "true"){
					split($1,psPmTok,",");
					split(psPmTok[1],psPmTok2," ");
					split(psPmTok[2],psPmTok3," ");
					_prmTHp=psPmTok2[3];
					_prmAGC=psPmTok3[2];
					
				}
				#print "extracted permgen _prmTHp:"_prmTHp" _prmBGC: "_prmBGC" _prmAGC: "_prmAGC
			break;
			case /Heap.*after.*GC.*invocations.*/:
				# Get the total GCs and total full GCs
				split($1,gcStatTok,"=");
				split(gcStatTok[2],gcStatTok1," ");
				_ttlAllGcs=gcStatTok1[1];
				_ttlFGcs=substr(gcStatTok1[3],1,length(gcStatTok1[3])-2);
				_ttlGcs=_ttlAllGcs-_ttlFGcs;
				#print "total gc: "_ttlGcs" total fgcs: "_ttlFGcs;
				if(_gcType == "GC"){
					# in this case we need to get values for Old Generation and Perm Gen from separate line. 
					_xtractOldPermAVals="true";
				}
				_xtractOldPermBVals="false";
			break;
			case /[0-9]{4}-[0-9]{2}-[0-9]{2}T.*/:
				_xtractOldPermBVals="false";
				# process date	
				split($1,tsTok,"T");
				_dt=tsTok[1];
				_tm=substr(tsTok[2],1,12);
				_tz=substr(tsTok[2],13,5);
				_hr=substr(tsTok[2],1,2);	
				#print "Full GC string: Date: "_dt" time: "_tm" tz: "_tz" hour: "_hr;
				if($2 ~ /Full.*GC/){
					if($2 ~ /.*Full.*GC.*\(System\).*/){
						_gcType="FULLGC_SYS";
					} else {
						_gcType="FULLGC";
					}
					_xtractOldPermAVals="false";					
					#process Full GC here
					_gcStr=substr($0,index($0,$3));
				} else {
					_gcType="GC";
					if($2 ~ /GC--/){
						_gcStr=substr($0,index($0,$3));
					}					
					#process minor GC in the next line.
				}
				#_lstPName=pName;
			break;
			case /.*PSYoungGen:.*/:
				_gcType="GC";
				_gcStr=substr($0,index($0,$1));					
			break;
			case /}/:
				#print "Processing for given GC invocation ends here.";
				_writeLn="true";					
				_xtractOldPermAVals="false";
				_xtractOldPermBVals="false";
			break;
			case /Completed.*parsing.*file:.*/:
				print $0;
				#print last record from previous file into Summary
				#print "Last record: " lstRcd;
				# Write into history file, only if it is report type is daily:
				if(rptType == "daily"){
					print pName,_gcType,_dt,_tm,_tz,_hr,_yngBGC,_yngAGC,_yngDiff,_yngTHp,_yngAGCPc,_oldBGC,_oldAGC,_oldDiff,_oldTHp,_oldAGCPc,_prmBGC,_prmAGC,_prmDiff,_prmTHp,_prmAGCPc,_hpTBGC,_hpTAGC,_hpDiff,_THp,_hpAGCPc,_usrTm,_sysTm,_rlTm,_rlTmUnt,_ttlGcs,_ttlFGcs,_ttlAllGcs >> rptGcHstAllFile;
				}
				# Write into summary file:
				printf lstBdFmt,pName,_gcType,_dt,_tm,_tz,_yngBGC,_yngAGC,_yngDiff,_yngTHp,_yngAGCPc,_oldBGC,_oldAGC,_oldDiff,_oldTHp,_oldAGCPc,_prmBGC,_prmAGC,_prmDiff,_prmTHp,_prmAGCPc,_hpTBGC,_hpTAGC,_hpDiff,_THp,_hpAGCPc,_rlTm,_ttlGcs,_ttlFGcs,_ttlAllGcs >> tempfGC".lstRcd";
			break;				
			default:
				#print "Unknown record: "$0" Skipping.";
			break;			
		}		 
		# process the _gcStr here
		if(_gcStr != "" ){
			#print "_gcStr "_gcStr;
			split(_gcStr,gcTok,"[");
			for (tok in gcTok){
				if(gcTok[tok] != "" && gcTok[tok] != " "){
					switch(gcTok[tok]){
						case /.*PSYoungGen:.*/:
							# if it is minor gc; then it has heap string separated by "\]"
							# PSYoungGen: 2546048K->32508K(2672384K)\] 4626942K->2113402K(8267520K), 0.1491728 secs\]
							_yngTmpStr1=substr(gcTok[tok],length("PSYoungGen: ")+1);
							split(_yngTmpStr1,yngTmpTok1,"]");
							split(yngTmpTok1[1],yngTmpTok2,"->");
							_yngBGC=yngTmpTok2[1];
							split(yngTmpTok2[2],yngTmpTok3,"(");
							_yngAGC=yngTmpTok3[1];
							_yngTHp=substr(yngTmpTok3[2],1,length(yngTmpTok3[2])-1);
							if(yngTmpTok1[2] != ""){
								# first split by "," to separate between Total heap and time
								split(yngTmpTok1[2],yngTmpTok4,",");
								split(yngTmpTok4[1],yngTmpTok5,"->");
								_hpTBGC=substr(yngTmpTok5[1],2); # removes the space in front
								split(yngTmpTok5[2],yngTmpTok6,"(");
								_hpTAGC=yngTmpTok6[1];
								_THp=substr(yngTmpTok6[2],1,length(yngTmpTok6[2])-1);
							}						
						break;
						case /ParOldGen:.*/:
							#ParOldGen: 5578700K->2080894K(5595136K)\] 5619916K->2080894K(8266944K)
							_oldTmpStr1=substr(gcTok[tok],length("ParOldGen: "));
							split(_oldTmpStr1,oldTmpTok1,"]");
							split(oldTmpTok1[1],oldTmpTok2,"->");
							_oldBGC=substr(oldTmpTok2[1],2);
							split(oldTmpTok2[2],oldTmpTok3,"(");
							_oldAGC=oldTmpTok3[1];
							_oldTHp=substr(oldTmpTok3[2],1,length(oldTmpTok3[2])-1);
							if(oldTmpTok1[2] != ""){
								split(oldTmpTok1[2],oldTmpTok4,"->");
								_hpTBGC=substr(oldTmpTok4[1],2); # removes the space in front
								split(oldTmpTok4[2],oldTmpTok5,"(");
								_hpTAGC=oldTmpTok5[1];
								_THp=substr(oldTmpTok5[2],1,length(oldTmpTok5[2])-2); # removing trailing bracket and space.
							}
							#print "inside ParOldGen:" gcTok[tok] ";_oldBGC"_oldBGC" ;_oldAGC:"_oldAGC" ;_oldTHp:"_oldTHp" ;_hpTBGC"_hpTBGC" ;_hpTAGC:"_hpTAGC" ;_THp:"_THp;
						break;
						case /.*PSPermGen:.*/:
							#PSPermGen: 590847K->590105K(741376K)], 3.6775195 secs\]
							_prmTmpStr1=substr(gcTok[tok],length("PSPermGen: "));
							# then split by "," to separate between Total heap and time
							split(_prmTmpStr1,prmTmpTok1,",");
							split(prmTmpTok1[1],prmTmpTok2,"->");
							_prmBGC=substr(prmTmpTok2[1],2);
							split(prmTmpTok2[2],prmTmpTok3,"(");
							_prmAGC=prmTmpTok3[1];
							_prmTHp=substr(prmTmpTok3[2],1,length(prmTmpTok3[2])-2);
							
						break;
						case /Times:.*/:
							#Times: user=27.09 sys=0.03, real=3.68 secs\]
							_tmTmpStr1=substr(gcTok[tok],length("Times: "));
							# first split by "," to separate real time
							split(_tmTmpStr1,tmTmpTok1,",");
							split(tmTmpTok1[1],tmTmpTok2," ");
							_usrTm=substr(tmTmpTok2[1],length("user=")+1);
							_sysTm=substr(tmTmpTok2[2],length("sys=")+1);
							split(tmTmpTok1[2],tmTmpTok3," ");
							_rlTm=substr(tmTmpTok3[1],length("real=")+1);
							_rlTmUnt=substr(tmTmpTok3[2],1,length(tmTmpTok3[2])-1);
						break;
						default:
							print "unrecognized string: "gcTok[tok];
						break;
						
					}
				}
			}
		}
		if(_writeLn == "true"){
			# logic to check the unit
			
			_unConvStr=_yngBGC","_yngAGC","_yngTHp","_oldBGC","_oldAGC","_oldTHp","_prmBGC","_prmAGC","_prmTHp","_hpTBGC","_hpTAGC","_THp;
			#print "unconverted string: "_unConvStr
			split(_unConvStr,uConTok,",");
			_convStr="";
			for(uc in uConTok){
				if(uConTok[uc] != ""){
					_val=substr(uConTok[uc],1,length(uConTok[uc])-1);
					_unt=substr(uConTok[uc],length(uConTok[uc]));
					#print "Value: "_val" ; unit: "_unt;
					switch (toupper(_unt)){
					case "K":
						#print "in switch K";
						_cVal=_val;
						break;
					case "B":
						_cVal=_val/1024;
						break;
					case "M":
						_cVal=_val*1024;
						break;
					case "G":
						_cVal=_val*1024*1024;
						break;
					case "N":
						_cVal="";
					break;
					default:
						print "Error ...Unable to convert unit for: "uConTok[uc]" from instance "_dt":"_tm" and Unconverted string:"_unConvStr;
						_cVal=_val;
						break;
					}
				} else {
					_cVal="";
				}
				
				if(length(_convStr) > 0)
					_convStr=_convStr","_cVal;
				else
					_convStr=_cVal;
			}
			
			#print "Converted string: "_convStr;
			# Calculate percentage and diff
			split(_convStr,convTok,",");
			_yngBGC=convTok[1];
			_yngAGC=convTok[2];
			_yngDiff=_yngBGC-_yngAGC;
			_yngTHp=convTok[3];
			_yngAGCPc=(_yngAGC/_yngTHp)*100;
			_oldBGC=convTok[4];
			_oldAGC=convTok[5];
			if(_oldBGC != "" && _oldAGC != "")
				_oldDiff=_oldBGC-_oldAGC;
			else
				_oldDiff="";
				
			_oldTHp=convTok[6];
			if(_oldTHp != "" &&  _oldTHp != 0)
				_oldAGCPc=(_oldAGC/_oldTHp)*100;
			else
				_oldAGCPc="";
			_prmBGC=convTok[7];
			_prmAGC=convTok[8];
			if(_prmBGC != "" && _prmAGC != "")
				_prmDiff=_prmBGC-_prmAGC;
			else
				_prmDiff="";
				
			_prmTHp=convTok[9];
			if(_prmTHp != "" && _prmTHp != 0)
				_prmAGCPc=(_prmAGC/_prmTHp)*100;
			else
				_prmAGCPc="";
			_hpTBGC=convTok[10];
			_hpTAGC=convTok[11];
			_hpDiff=_hpTBGC-_hpTAGC;
			_THp=convTok[12];
			if(_THp != "" && _THp != 0){
				_hpAGCPc=(_hpTAGC/_THp)*100;
			} else {
				_hpAGCPc="";
			}
			#Calculate sums in order to calculate average - only for given date
			summarize="false";
			if(PO == "full" && _dt <= recDate){
					summarize="true";
			} else {
				if(PO == "partial" && _dt == recDate){
					summarize="true";
				}
			}
			if(summarize == "true"){
				arrJvm[pName" "_dt];
				switch (_gcType){
					case "FULLGC_SYS":
						fullGCSysCnt[pName" "_dt]++;
						arrRlTmFgcSysSm[pName" "_dt]+=_rlTm;
						break;
					case "FULLGC":
						fullGCCnt[pName" "_dt]++;
						arrRlTmFgcSm[pName" "_dt]+=_rlTm;
						break;						
					case "GC":
						gCCnt[pName" "_dt]++;
						arrRlTmGcSm[pName" "_dt]+=_rlTm;
						break;
					default:
						print "Error ... Unknown GC type: "_gcType " encountered";
						break;			
				}
				if(_gcType ~ /(FULLGC|FULLGC_SYS)/){
					# compare old Gen space and Perm Gen space against threshold values. Check this after full gc.				
					_jvmPrfx=substr(pName,1,3);
					thKeyfgcOGA="jvm."_jvmPrfx".fgcOldGenAfTh";
					thValfgcOGA=arrTh[thKeyfgcOGA];
					thKeyfgcPGA="jvm."_jvmPrfx".fgcPGenAfTh";
					thValfgcPGA=arrTh[thKeyfgcPGA];
					if(thValfgcOGA !="" && _oldAGC > thValfgcOGA) {
						arrOldGcExd[pName","thValfgcOGA]++;
						#print _oldAGC"(K) : Old Generation Heap space after Full GC exceeded threshold of " thValfgcOGA"(K) at "_dt":"_tm". There is possibility of OutOfMemory in near future because of Not sufficient Heap space for "pName >> rptAlertFile;
					}
					if(thValfgcPGA !="" && _prmAGC > thValfgcPGA) {
						arrPGcExd[pName","thValfgcPGA]++;
						#print _prmAGC"(K) : Perm Generation Heap space after Full GC exceeded threshold of "thValfgcPGA"(K) at "_dt":"_tm" There is possibility of OutOfMemory in near future because of Not sufficient PermGen Space for "pName >> rptAlertFile;
					}
				}
				print pName,_gcType,_dt,_tm,_tz,_hr,_yngBGC,_yngAGC,_yngDiff,_yngTHp,_yngAGCPc,_oldBGC,_oldAGC,_oldDiff,_oldTHp,_oldAGCPc,_prmBGC,_prmAGC,_prmDiff,_prmTHp,_prmAGCPc,_hpTBGC,_hpTAGC,_hpDiff,_THp,_hpAGCPc,_usrTm,_sysTm,_rlTm,_rlTmUnt,_ttlGcs,_ttlFGcs,_ttlAllGcs >> tempfGC".vgc.all";
			}
			#lstRcd="gc tokens: gcType: "_gcType" pName: "pName" Date: "_dt" time: "_tm" tz: "_tz" hour: "_hr" _yngBGC: "_yngBGC" _yngAGC: "_yngAGC" _yngTHp: "_yngTHp" _yngAGCPc: "_yngAGCPc" _oldBGC: "_oldBGC" _oldAGC: "_oldAGC" _oldTHp: "_oldTHp" _oldAGCPc:" _oldAGCPc" _prmBGC: "_prmBGC" _prmAGC: "_prmAGC" _prmTHp: "_prmTHp" _prmAGCPc: "_prmAGCPc" _hpTBGC: "_hpTBGC" _hpTAGC: "_hpTAGC" _THp: "_THp" _hpAGCPc: "_hpAGCPc" _usrTm: "_usrTm" _sysTm: "_sysTm" _rlTm: "_rlTm" _rlTmUnt: "_rlTmUnt;									
			#print pName,_gcType,_dt,_tm,_tz,_hr,_yngBGC,_yngAGC,_yngDiff,_yngTHp,_yngAGCPc,_oldBGC,_oldAGC,_oldDiff,_oldTHp,_oldAGCPc,_prmBGC,_prmAGC,_prmDiff,_prmTHp,_prmAGCPc,_hpTBGC,_hpTAGC,_hpDiff,_THp,_hpAGCPc,_usrTm,_sysTm,_rlTm,_rlTmUnt,_ttlGcs,_ttlFGcs,_ttlAllGcs >> tempfGC".vgc.all";
			
		}
		
	} END {
		#print "======summary ======";
		if(length(arrOldGcExd) > 0){
			for(ogce in arrOldGcExd){
				split(ogce,ogceTok,",");
				print "Old Generation Heap space after Full GC exceeded "arrOldGcExd[ogce]" times threshold of " ogceTok[2]"(K) for "ogceTok[1]". There is possibility of OutOfMemory in near future because of Not sufficient Heap space" >> rptAlertFile;
			}
		}
		if(length(arrPGcExd) > 0){
			for(pgce in arrPGcExd){
				split(pgce,pgceTok,",");
				print "Perm Generation Heap space after Full GC exceeded "arrPGcExd[pgce]" times threshold of " pgceTok[2]"(K) on "pgceTok[1]". There is possibility of OutOfMemory in near future because of Not sufficient Heap space" >> rptAlertFile;
			}
		}
		if(length(arrJvm) > 0){			
			for(_jvm in arrJvm){
				egcCnt="0";
				efGcCnt="0";
				eRlTmFgc="0";
				eRlTmGc="0";
				avgRlTmFgcSm="0";
				avgRlTmGcSm="0";
				if(fullGCCnt[_jvm] != ""){
					efGcCnt=fullGCCnt[_jvm];					
				}
				
				if(gCCnt[_jvm] != ""){
					egcCnt=gCCnt[_jvm];
					
				}
				
				if(efGcCnt > 0 ){
					eRlTmFgc=arrRlTmFgcSm[_jvm];
					avgRlTmFgcSm=eRlTmFgc/efGcCnt;
				} 
							
				if(egcCnt > 0){
					eRlTmGc=arrRlTmGcSm[_jvm]
					avgRlTmGcSm=eRlTmGc/egcCnt;
				} 				
				ttlRlTm=eRlTmFgc+eRlTmGc;
				tgcCnt=efGcCnt+egcCnt;
				split(_jvm,jvmTok," ");
				OFS=" ";
				print _jvm,avgRlTmGcSm,avgRlTmFgcSm,eRlTmGc,eRlTmFgc,ttlRlTm,egcCnt,efGcCnt,tgcCnt >> tempfGC".summary";
				_jvmPrfx=substr(_jvm,1,3);
				thKeyfgcCnt="jvm."_jvmPrfx".fgcDlyCountTh";
				thValfgcCnt=arrTh[thKeyfgcCnt];
				#print "ThKey: "thKeyfgcCnt" val: "thValfgcCnt;
				if(thValfgcCnt !="" && efGcCnt > thValfgcCnt) {
					print efGcCnt" : number of Full GC exceeds threshold of "thValfgcCnt" for "jvmTok[1]" on "jvmTok[2] >> rptAlertFile;
				}
			}
		
		}
		
	
	}'
	
if [[ -e $tempfGC.vgc.all ]]; then
	mv $tempfGC.vgc.all $rptGcFile
fi

if [[ -e $tempfGC.summary ]]; then
	sort -t' ' -k1,1 -k2,2 $tempfGC.summary | \
	awk -vtempfGC=$tempfGC -vrecDate=$recDate 'BEGIN \
	{
		FS=" ";
		print "=====================================================" > tempfGC".summary.sorted";
		print "===== Verbose GC analysis report =====" >> tempfGC".summary.sorted";
		print "===== based on native_stdout.log dated: "recDate"  =====" >> tempfGC".summary.sorted";
		print "=====================================================" >> tempfGC".summary.sorted";
		print "" >> tempfGC".summary.sorted";		
		print "===== Summary table contains short heading title. See below for their description =====" >> tempfGC".summary.sorted";
		pSFmt="%-8s\t%-70s\n";
		printf pSFmt, "date",": Date " >> tempfGC".summary.sorted";		
		printf pSFmt, "time",": Time " >> tempfGC".summary.sorted";
		printf pSFmt, "tz",": Time Zone " >> tempfGC".summary.sorted";
		printf pSFmt, "jvm",": Java Virtual Machine, may be interchangeably used with was or srv in reports." >> tempfGC".summary.sorted";
		printf pSFmt,"artgc",": Average Real Time for Minor GC " >> tempfGC".summary.sorted";
		printf pSFmt,"artfgc",": Average Real Time for Full or Major GC " >> tempfGC".summary.sorted";
		printf pSFmt,"trtgc",": Total Real Time for Minor GC " >> tempfGC".summary.sorted";
		printf pSFmt,"trtfgc",": Total Real Time for Full or Major GC" >> tempfGC".summary.sorted";
		printf pSFmt,"rt",": Real Time for GC or Full or Major GC" >> tempfGC".summary.sorted";
		printf pSFmt,"trt",": Total Real Time - includes both Minor GC and Major GC" >> tempfGC".summary.sorted";
		printf pSFmt,"gccnt",": Total Minor GC count for a given period (date)" >> tempfGC".summary.sorted";
		printf pSFmt,"gccntsr",": Total Minor GC count since restart of JVM" >> tempfGC".summary.sorted";
		printf pSFmt,"fgccnt",": Total Full or Major GC count for a given period (date)" >> tempfGC".summary.sorted";
		printf pSFmt,"fgccntsr",": Total Full or Major GC count since restart of JVM" >> tempfGC".summary.sorted";
		printf pSFmt,"tgccnt",": Total All (Minor GC plus Major GC) count for a given period (date) " >> tempfGC".summary.sorted";
		printf pSFmt,"tgccntsr",": Total All (Minor GC plus Major GC) count since restart of JVM " >> tempfGC".summary.sorted";
		printf pSFmt,"gctp",": Garbage Collection (GC) Type - (Minor)GC or FULLGC " >> tempfGC".summary.sorted";
		printf pSFmt,"ygub(K)",": Young Generation Used Before GC (K)" >> tempfGC".summary.sorted";
		printf pSFmt,"ygua(K)",": Young Generation Used After GC (K)" >> tempfGC".summary.sorted";
		printf pSFmt,"ygdf(K)",": Young Generation Difference Before and After GC" >> tempfGC".summary.sorted";
		printf pSFmt,"ygta(K)",": Young Generation Total Allocated  After GC" >> tempfGC".summary.sorted";
		printf pSFmt,"ygua%",": Young Generation Used Percentage After GC" >> tempfGC".summary.sorted";
		printf pSFmt,"ogub(K)",": Old Generation Used Before GC (K)" >> tempfGC".summary.sorted";
		printf pSFmt,"ogua(K)",": Old Generation Used After GC (K)" >> tempfGC".summary.sorted";
		printf pSFmt,"ogdf(K)",": Old Generation Difference Before and After GC" >> tempfGC".summary.sorted";
		printf pSFmt,"ogta(K)",": Old Generation Total Allocated  After GC" >> tempfGC".summary.sorted";
		printf pSFmt,"ogua%",": Old Generation Used Percentage After GC" >> tempfGC".summary.sorted";
		printf pSFmt,"pgub(K)",": Perm Generation Used Before GC (K)" >> tempfGC".summary.sorted";
		printf pSFmt,"pgua(K)",": Perm Generation Used After GC (K)" >> tempfGC".summary.sorted";
		printf pSFmt,"pgdf(K)",": Perm Generation Difference Before and After GC" >> tempfGC".summary.sorted";
		printf pSFmt,"pgta(K)",": Perm Generation Total Allocated  After GC" >> tempfGC".summary.sorted";
		printf pSFmt,"pgua%",": Perm Generation Used Percentage After GC" >> tempfGC".summary.sorted";
		printf pSFmt,"hgub(K)",": Heap Used Before GC (K)" >> tempfGC".summary.sorted";
		printf pSFmt,"hgua(K)",": Heap Used After GC (K)" >> tempfGC".summary.sorted";
		printf pSFmt,"hgdf(K)",": Heap Difference Before and After GC" >> tempfGC".summary.sorted";
		printf pSFmt,"hgta(K)",": Heap Total Allocated  After GC" >> tempfGC".summary.sorted";
		printf pSFmt,"hgua%",": Heap Used Percentage After GC" >> tempfGC".summary.sorted";			
		print "=====================================================" >> tempfGC".summary.sorted";
		gcSumHdFmt="%-15s\t%-10s\t%7s\t%7s\t%7s\t%10s\t%10s\t%4s\t%4s\t%5s\n";
		gcSumBdFmt="%-15s\t%10s\t%7.3f\t%7.3f\t%7.3f\t%10.3f\t%10.3f\t%4d\t%4d\t%5d\n";
		printf gcSumHdFmt,"jvm","date","artgc","artfgc","trtgc","trtfgc","trt","gccnt","fgccnt","tgccnt" >> tempfGC".summary.sorted";
	}						
	{
		printf gcSumBdFmt,$1,$2,$3,$4,$5,$6,$7,$8,$9,$10 >> tempfGC".summary.sorted";
	}'	
	echo "" >> $tempfGC.summary.sorted
	echo "" >> $tempfGC.summary.sorted
	echo "========= Last Verbose GC  record for each JVM parsed and extracted from native_stdout.log =========" >> $tempfGC.summary.sorted
	echo "" >> $tempfGC.summary.sorted
	cat $tempfGC.lstRcd >> $tempfGC.summary.sorted
	mv $tempfGC.summary.sorted $rptGcSumFile
fi

echo "========== END of GC Alert Section ==========" >> $rptAlertFile;
	
trap 'rm -f $tempfGC*' EXIT INT TERM

echo "$0 completed at: "$(date +"%Y-%m-%dT%H:%M:%S")" with total execution time: "$SECONDS" sec" 2>&1 | tee -a $parserExeLog
echo "==================================================================" 2>&1 | tee -a $parserExeLog
