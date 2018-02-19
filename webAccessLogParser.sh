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
#	Parses Apache/IBM HTTP Server access_log. 
# Produces Alert.log, summary reports and historical reports.
# Execute as:
# ./webAccessLogParser.sh <options>
#
# Execute below command to see all the available options:
# ./webAccessLogParser.sh

# Include usage
source ./usage.sh

echo "==================================================================" 2>&1 | tee -a $parserExeLog
echo "$0 started at: "$(date +"%Y-%m-%dT%H:%M:%S") 2>&1 | tee -a $parserExeLog
echo "Processing logs with the following input command line:" 2>&1 | tee -a $parserExeLog
echo "$cmdln" 2>&1 | tee -a $parserExeLog;

#--------- Input files ---------------#
fWasCloneIdsMap=./WAS_CloneIDs.csv
fBaseLine=./perfBaseLine.csv
fTh=./thresholdValues.csv

#--------- Report/Output files -------#
rptAlertFile="$rptDir/00_Alert.txt";
rptSummaryFile="$rptDir/02_WebAccessLogSummaryRpt.txt";
rptAccessLogAllFile="$rptDir/WebAccessLogRpt_all.csv";
rptDiscardedRecordsFile="$rptDir/WebAccessLog_discardedRpt.csv";
rptSummaryByDomain="$rptDir/WebAccessLogSummaryByDomainRpt.csv";
rptAvgRespTimeByURIFile="$rptDir/WebAccessLogSummaryByTransactionRpt.csv";
rptPerfByUIDFile="$rptDir/WebAccessLogSummaryByUIDRpt.csv";
rptSummaryBy400PlsUrl="$rptDir/WebAccessLogSummaryByRC400PlusURLRpt.csv";
rptSummaryUserSession="$rptDir/WebAccessLogSummaryByUidSessionRpt.csv";
rptUnknowUA="$rptDir/WebAccessLogSummaryUnknowUARpt.csv";
rptDomainUsgByUidByHr="$rptDir/WebHourlyDomainUsageByUid.csv";
rptDomainUsgBySessByHr="$rptDir/WebHourlyDomainUsageBySess.csv";
rptDomainUsgByDay="$rptDir/WebDlyDomainUsage.csv";

#--------- History Report/Output files -------#
# These are historical reports. Each run will append record in existing report file.
# If historical file does not exist, create and add heading.

rptPerfHistFile="$pDir/WebPerfHistoryRpt.csv";
if [[ ! -e $rptPerfHistFile && $rptType == "daily" ]]; then
	echo "===== Summary table contains short heading title. See below for their description =====" > $rptPerfHistFile;
	echo "date 	: Date" >> $rptPerfHistFile;
	echo "uuc  	: unique user count" >> $rptPerfHistFile;
	echo "usc  	: unique jSession count" >> $rptPerfHistFile;
	echo "art  	: average response time in sec" >> $rptPerfHistFile;
	echo "<=1  	: response time less than or equal to 1 seconds range in percentage" >> $rptPerfHistFile;
	echo "<=5  	: response time greater than 1 seconds but less than or equal to 5 seconds range in percentage" >> $rptPerfHistFile;
	echo "<=10 	: response time greater than 5 seconds but less than or equal to 10 seconds range in percentage " >> $rptPerfHistFile;
	echo "<=20 	: response time greater than 10 seconds but less than or equal to 20 seconds range in percentage" >> $rptPerfHistFile;
	echo ">20  	: response time greater than 20 seconds range in percentage" >> $rptPerfHistFile;
	echo "xrc  	: Http request/response count excluding static contents like jpg|gif|png|ico|js|cgi|css|htm|html|pdf|null|doc|xlsx|xsl|aspx|txt|.css.xhtml|.js.xhtml|.png.xhtml|.gif.xhtml" >> $rptPerfHistFile;
	echo "irc		: Http request/response count including static contents static contents" >> $rptPerfHistFile;
	echo "=====================================================" >> $rptPerfHistFile;
  echo "date|uuc|usc|<=1|<=5|<=10|<=20|>20|art|xrc|irc" >> $rptPerfHistFile;
fi
rptHrlyAvgHistFile="$pDir/WebHourlyAvgRespTimeHistoryRpt.csv";
if [[ ! -e $rptHrlyAvgHistFile && $rptType == "daily" ]]; then
	echo "date|H0|H1|H2|H3|H4|H5|H6|H7|H8|H9|H10|H11|H12|H13|H14|H15|H16|H17|H18|H19|H20|H21|H22|H23" > $rptHrlyAvgHistFile;
fi
rptUnqUsrHrlyHistFile="$pDir/WebUniqueUsersHourlyHistoryRpt_all.csv";
if [[ ! -e $rptUnqUsrHrlyHistFile && $rptType == "daily" ]]; then
	echo "date|H0|H1|H2|H3|H4|H5|H6|H7|H8|H9|H10|H11|H12|H13|H14|H15|H16|H17|H18|H19|H20|H21|H22|H23" > $rptUnqUsrHrlyHistFile;
fi
rptRqstTypeByHostHistFile="$pDir/WebRequestTypeHistoryRpt.csv";
if [[ ! -e $rptRqstTypeByHostHistFile && $rptType == "daily" ]]; then
	echo "date|webserver|GET|POST|PUT|HEAD|OPTIONS|CONNECT|DELETE|TRACE|PROFIND|SEARCH|PROPATCH|SECURE|MKCOL" > $rptRqstTypeByHostHistFile;
fi
rptRspByCodeHistFile="$pDir/WebResponseCodeHistoryRpt.csv";
if [[ ! -e $rptRspByCodeHistFile && $rptType == "daily" ]]; then
	echo "date|webserver|100|101|102|103|200|201|202|203|204|205|206|207|208|226|300|301|302|303|304|305|306|307|308|400|401|402|403|404|405|406|407|408|409|410|411|412|413|414|415|416|417|418|419|420|421|422|423|424|426|428|429|431|440|444|449|450|451|495|496|497|498|499|500|501|502|503|504|505|506|507|508|509|510|511|520|521|523|524|525|526" > $rptRspByCodeHistFile;
fi
rptStatByIHSHistFile="$pDir/WebStatsByIHSHistoryRpt.csv";
if [[ ! -e $rptStatByIHSHistFile && $rptType == "daily" ]]; then
	echo "===== Summary table contains short heading title. See below for their description =====" > $rptStatByIHSHistFile;
	echo "date 	: Date" >> $rptStatByIHSHistFile;
	echo "ws  	: web server" >> $rptStatByIHSHistFile;
	echo "uuc  	: unique user count" >> $rptStatByIHSHistFile;
	echo "usc  	: unique jSession count" >> $rptStatByIHSHistFile;
	echo "art  	: average response time in sec" >> $rptStatByIHSHistFile;
	echo "<=1  	: response time less than or equal to 1 seconds range in percentage" >> $rptStatByIHSHistFile;
	echo "<=5  	: response time greater than 1 seconds but less than or equal to 5 seconds range in percentage" >> $rptStatByIHSHistFile;
	echo "<=10 	: response time greater than 5 seconds but less than or equal to 10 seconds range in percentage " >> $rptStatByIHSHistFile;
	echo "<=20 	: response time greater than 10 seconds but less than or equal to 20 seconds range in percentage" >> $rptStatByIHSHistFile;
	echo ">20  	: response time greater than 20 seconds range in percentage" >> $rptStatByIHSHistFile;
	echo "xrpc  : Http request/response count in percentage excluding static contents like jpg|gif|png|ico|js|cgi|css|htm|html|pdf|null|doc|xlsx|xsl|aspx|txt|.css.xhtml|.js.xhtml|.png.xhtml|.gif.xhtml" >> $rptStatByIHSHistFile;
	echo "irpc	: Http request/response count including static contents static contents in percentage" >> $rptStatByIHSHistFile;
	echo "=====================================================" >> $rptStatByIHSHistFile;
	echo "date|ws|uuc|usc|art|<=1|<=5|<=10|<=20|>20|xrpc|irpc" >> $rptStatByIHSHistFile;
fi
rptStatByWASHistFile="$pDir/WebStatsByWASHistoryRpt.csv";
if [[ ! -e $rptStatByWASHistFile && $rptType == "daily" ]]; then
	echo "===== Summary table contains short heading title. See below for their description =====" > $rptStatByWASHistFile;
	echo "date 	: Date" >> $rptStatByWASHistFile;
	echo "was  	: WebSphere Applicaton Server" >> $rptStatByWASHistFile;
	echo "uuc  	: unique user count" >> $rptStatByWASHistFile;
	echo "usc  	: unique jSession count" >> $rptStatByWASHistFile;
	echo "art  	: average response time in sec" >> $rptStatByWASHistFile;
	echo "<=1  	: response time less than or equal to 1 seconds range in percentage" >> $rptStatByWASHistFile;
	echo "<=5  	: response time greater than 1 seconds but less than or equal to 5 seconds range in percentage" >> $rptStatByWASHistFile;
	echo "<=10 	: response time greater than 5 seconds but less than or equal to 10 seconds range in percentage " >> $rptStatByWASHistFile;
	echo "<=20 	: response time greater than 10 seconds but less than or equal to 20 seconds range in percentage" >> $rptStatByWASHistFile;
	echo ">20  	: response time greater than 20 seconds range in percentage" >> $rptStatByWASHistFile;
	echo "xrpc  : Http request/response count in percentage excluding static contents like jpg|gif|png|ico|js|cgi|css|htm|html|pdf|null|doc|xlsx|xsl|aspx|txt|.css.xhtml|.js.xhtml|.png.xhtml|.gif.xhtml" >> $rptStatByWASHistFile;
	echo "irpc	: Http request/response count including static contents static contents in percentage" >> $rptStatByWASHistFile;
	echo "=====================================================" >> $rptStatByWASHistFile;
	echo "date|was|uuc|usc|art|<=1|<=5|<=10|<=20|>20|xrpc|irpc" >> $rptStatByWASHistFile;
fi

# performance (response time) range list.
# <=1  : response time less than or equal to 1 seconds .
# <=5  : response time greater than 1 seconds but less than or equal to 5 seconds.
# <=10 : response time greater than 5 seconds but less than or equal to 10 seconds.
# <=20 : response time greater than 10 seconds but less than or equal to 20 seconds.
# >20  : response time greater than 20 seconds.
rangeLst="<=1|<=5|<=10|<=20|>20";

fTempHttp=`mktemp`

if [[ "$currDate" == "$recDate" ]]
   then
	logFileName=access_log	
   else
	logFileName=access_log.$rec0MM$rec0DD$recYY	
fi

echo "" >> $parserExeLog
echo "========== Start of Web Access Log Alert Section ==========" >> $rptAlertFile
files=$(find $rootcontext  -name $logFileName -type f);

if [[ "${files}" == "" ]]; then
	echo "No log file found to process. exiting ...";
	exit 1;
fi 
for z in $files; do
	echo "Processing file: $z" >> $parserExeLog;
	cat $z | grep -F "[$rec0DD/$recLM/$recYYYY"  
done | \
awk -vrecDate=$recDate -vrptDir=$rptDir -vpDir=$pDir -vrptType=$rptType -vfWasCloneIdsMap=$fWasCloneIdsMap -vrangeLst=$rangeLst \
	-vfBaseLine=$fBaseLine -vfTh=$fTh -vfTempHttp=$fTempHttp \
	-valrtF=$rptAlertFile  \
	-vrptHrlyAvgHistFile=$rptHrlyAvgHistFile -vrptUnqUsrHrlyHistFile=$rptUnqUsrHrlyHistFile -vrptPerfHistFile=$rptPerfHistFile \
	-vrptDomainPerfHistFile=$rptDomainPerfHistFile -vrptDiscardedRecordsFile=$rptDiscardedRecordsFile -vrptRqstTypeByHostHistFile=$rptRqstTypeByHostHistFile \
	-vrptRspByCodeHistFile=$rptRspByCodeHistFile -vrptStatByIHSHistFile=$rptStatByIHSHistFile -vrptStatByWASHistFile=$rptStatByWASHistFile \
	'BEGIN {
		FS="( \"|\" )";
		OFS="|";
		#access log sort command, sort by response time (field 22)
		#accslgsortcmd="sort -t\"|\" -k22nr >> fTempHttp\".access_log_all\"";
		whuidsrtcmd="sort -k5 >> "fTempHttp".whereuid";
		# discarded record count
		discRecCnt=0;
		# non-discarded record count
		rcdCnt=0;
		split(rangeLst,arrRangeName,"|");
		# temporary work-around to get MM from short month like "Jan"
		mntStr="Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec";
		split(mntStr,mntStrArr,",");
		for(idx in mntStrArr){
			mnt=mntStrArr[idx]; 
			mntArr[mnt]=idx;
		}
		
		# Get the threshold values
		while((getline thln < fTh) > 0){
			# first line is heading. Ignore
			split(thln,arrThln,"|");
			if(arrThln[3] == "http"){
				arrTh[arrThln[1]]=arrThln[2];
				#print "reading threshold values: " NR, arrThln[1],arrThln[2];				
			}
		}
		close(thln);
		close(fTh);
		
		
		# Get the mapping of cloneIDs and WAS Server
		while((getline clndln < fWasCloneIdsMap) > 0){
			split(clndln,arrWasCloneIDsLn,"|");
			arrWasCloneIDs[arrWasCloneIDsLn[1]]=arrWasCloneIDsLn[2];			
		}
		close(clndln);
		close(fWasCloneIdsMap);
		
		
		#Initialize array for User count by Hour
		for (i=0; i < 24; i++){
			if(i<10){
				j=0i;
			} else {
				j=i;
			}
			for(rngIdx in arrRangeName){
				arrHrlRange[j","arrRangeName[rngIdx]]=0;				
			}				
		}
		#Initialize the baseline performance
		if(fBaseLine != ""){
			while((getline bsln < fBaseLine) > 0){
				split(bsln,arrBslineLn,"|");
				arrBaseLine[arrBslineLn[1]]=arrBslineLn[2];				
			}
			close(bsln);
			close(fBaseLine);
		}
		
		
		print "=====================================================" > fTempHttp".summary";
		print "===== Http Access log analysis report =====" >> fTempHttp".summary";
		print "===== based on access logs dated: " recDate"  =====" >> fTempHttp".summary";
		print "=====================================================" >> fTempHttp".summary";
		print "" >> fTempHttp".summary";		
		print "===== Summary table contains short heading title. See below for their description =====" >> fTempHttp".summary";
		print "Note: Hourly statistics excludes the following static contents from calculation:" >> fTempHttp".summary";
		print "excludes with these extensions: " >> fTempHttp".summary";
		pSFmt="%-5s\t%-70s\n";
		printf pSFmt,"hr",": Hour " >> fTempHttp".summary";
		printf pSFmt,"date",": Date " >> fTempHttp".summary";
		printf pSFmt,"time",": Time " >> fTempHttp".summary";
		printf pSFmt,"uid",": User ID" >> fTempHttp".summary";
		printf pSFmt,"js",": jSession" >> fTempHttp".summary";
		printf pSFmt,"was",": WebSphere Application Server or App Server" >> fTempHttp".summary";
		printf pSFmt,"ws",": Web Server like Apache or IBM HTTP Server (IHS)" >> fTempHttp".summary";
		printf pSFmt,"jvm",": Java Virtual Machine (JVM)" >> fTempHttp".summary";
		printf pSFmt,"req",": HTTP Request like GET, POST etc." >> fTempHttp".summary";
		printf pSFmt,"rsp",": HTTP Response code like 200, 400 etc." >> fTempHttp".summary";
		printf pSFmt,"sz",": Size - HTTP response size" >> fTempHttp".summary";
		printf pSFmt,"uuc",": Unique User Count" >> fTempHttp".summary"; 
		printf pSFmt,"uupc",": Unique User Count in Percentage " >> fTempHttp".summary"; 
		printf pSFmt,"usc",": Unique jSession Count" >> fTempHttp".summary";
		printf pSFmt,"uspc",": Unique jSession Count in Percentage" >> fTempHttp".summary";
		printf pSFmt,"art",": Average Response Time in Second" >> fTempHttp".summary";
		printf pSFmt,"bart",": Baseline Average Response Time in Second" >> fTempHttp".summary";
		printf pSFmt,"rt",": (HTTP) Response Time in Second" >> fTempHttp".summary";
		printf pSFmt,"mnrt",": Minimum Response Time in Second for the given access request or transaction" >> fTempHttp".summary";
		printf pSFmt,"mxrt",": Maximum Response Time in Second for the given access request or Transaction" >> fTempHttp".summary";
		printf pSFmt,"rng",": Response Range (second). What range like 1 second, 5 second etc. range the response falls." >> fTempHttp".summary";
		printf pSFmt,"<=1",": Less than or eaual to One Second response range in percentage" >> fTempHttp".summary";
		printf pSFmt,"<=5",": Greater than One Second and less than or equal to Five Seconds response range in percentage" >> fTempHttp".summary";
		printf pSFmt,"<=10",": Greater than Five Seconds and less than or equal to Ten Seconds response range in percentage" >> fTempHttp".summary";
		printf pSFmt,"<=20",": Greater than Ten seconds and less than or equal to Twenty Seconds response range in percentage" >> fTempHttp".summary";
		printf pSFmt,">20",": More than Twenty Seconds in Percentage" >> fTempHttp".summary";
		printf pSFmt,"xrc",": Total Record (Request,Response or Transaction) Count - that excludes static contents like jpg|gif|png|ico|js|cgi|css|htm|html|pdf|null|doc|xlsx|xsl|aspx|txt|.css.xhtml|.js.xhtml|.png.xhtml|.gif.xhtml. " >> fTempHttp".summary";
		printf pSFmt,"xrpc",": Total Record (Request,Response or Transaction) Count in Percentage - that excludes static contents like jpg|gif|png|ico|js|cgi|css|htm|html|pdf|null|doc|xlsx|xsl|aspx|txt|.css.xhtml|.js.xhtml|.png.xhtml|.gif.xhtml. " >> fTempHttp".summary";
		printf pSFmt,"irc",": Total Record (Request,Response or Transaction) Count - that includes static contents. " >> fTempHttp".summary";
		printf pSFmt,"irpc",": Total Record (Request,Response or Transaction) Count in Percentage - that includes static contents. " >> fTempHttp".summary";
		printf pSFmt,"cnt",": (Any) Count like jSession count, User count etc. " >> fTempHttp".summary";
		printf pSFmt,"pc",": (Any) Count or measure represented in Percentage" >> fTempHttp".summary";
		printf pSFmt,"srv",": Server - like Web Server(IHS), App Server etc." >> fTempHttp".summary";
		printf pSFmt,"url",": URL" >> fTempHttp".summary";
		printf pSFmt,"bwsr",": Browser" >> fTempHttp".summary";
		print "=====================================================" >> fTempHttp".summary";
		print "Host","Date","Time","tz","Hour","JSession","CloneID","WAS","Domain","Page","Extension","URL","Params","Protocol","Request","Response","Size","ByteRcvd","ByteSent","UID","RespTimeInSec","RangeInSec","Browser","OS","OS Flavor","OS Ver" > fTempHttp".discarded";
		
		
	}
	{
		# This particular script is written to parse the access_log in the following format:
		#LogFormat "%h %l %u %t \"%r\" %>s %b JSESSIONID=\"%{JSESSIONID}C\" UID=\"%{UID}C\" %D %I %O \"%{User-agent}i\" %v" common
		# Apache log format: http://httpd.apache.org/docs/current/mod/mod_log_config.html
		#	%h: remote client host.
		#	%l: remote logname from identd, if supplied; requires mod_ident and IdentityCheck set On.
		#	%u: remote user from auth; may be bogus if return status (%s) is 401.
		#	%t: time the request was received.
		#	%r: first line of request
		#	%>s: the status code sent from the server to the client, e.g. 200, 404 etc.
		#	%b: the size of the response to the client, in bytes.
		#	%D: the time taken to serve the request, in microseconds.
		#	%{JSESSION}C: The contents of cookie JSESSION in the request sent to the server. Only version 0 cookies are fully supported.
		#	%{UID}C: The contents of cookie UID in request sent to the server.
		#	%I: bytes received, including request and headers, cannot be zero; requires mod_logio enabled.
		#	%O: Bytes sent, including headers, cannot be zero; requires mod_logio to use this.
		#	%{User-agent}i: the content of User-agent: header line in the request sent to the server.
		#	%v: the (canonical) server name of the server serving the request
		#Typical access_log record looks like the following:
		#xx.xxx.xxx.xx - - [13/Jun/2015:10:32:04 -0400] "GET /DashBoard/global/images/application-logoen.png HTTP/1.1" 200 66497 JSESSIONID="00006zV1pGhZFY7Gg2P1nzrkjyd:19670enb4" UID="abc.def@xyz.com" 162452 1545 67052 "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)" srvwebxxxxx0x0
		#xx.xxx.xxx.xx - abc.def@xyz.com [13/Jun/2015:10:32:04 -0400] "GET /DashBoard/global/js/devGlobal.js HTTP/1.1" 200 3212 JSESSIONID="00006zV1pGhZFY7Gg2P1nzrkjyd:19670enb4" UID="abc.def@xyz.com" 225677 1534 3649 "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)" srvwebxxxxx0x0
		
		#---Process 1st field
		#xx.xxx.xxx.xx - abc.def@xyz.com [13/Jun/2015:10:32:03 -0400]
		fld1=$1;
		# Tokenize first field
		split(fld1,arr1stFld," ");
		split(arr1stFld[4],arrTs,":");
		# Date
		dt=substr(arrTs[1],2);
		split(dt,arrDt,"/");
		_dd=arrDt[1];
		_mnt=arrDt[2];
		_mm=mntArr[_mnt];
		_yyyy=arrDt[3];
		
		# Time
		tm=arrTs[2]":"arrTs[3]":"arrTs[4];
		# hour
		hour=arrTs[2];
		_min=arrTs[3];
		_sec=arrTs[4];
		# timezone
		tz=substr(arr1stFld[5],1,5);
		_stdTmStr=_yyyy" "_mm" "_dd" "hour" "_min" "_sec" "tz;
		tmInSec=mktime(_stdTmStr);
		
		#---Process 2nd field
		#GET /ClntIdxWb/pages/client/clntSearch.faces?ctx=com.sysg.finMgmt HTTP/1.1
		fld2=$2;
		# Tokenize 2nd field
		split(fld2,arr2ndFld," ");
		_request=arr2ndFld[1];
		
		if(_request ~ /(^GET$|^POST$|^PUT$|^HEAD$|^OPTIONS$|^CONNECT$|^DELETE$|^TRACE$|^SECURE$|^SEARCH$|^PROPATCH$|^PROFIND$|^MKCOL$)/){
			request = _request;
			preParams="";
		} else {
			#some urls are like this: "eventId=409970&consentComments=&finMgmtExpand=falseGET /SysgSso/redirect.jsp HTTP/1.1"
			switch(_request){
				case /.*GET$/:
					request="GET";					
				break;
				case /.*POST$/:
					request="POST";					
				break;
				case /.*PUT$/:
					request="PUT";					
				break;
				case /.*HEAD$/:
					request="HEAD";					
				break;
				case /.*OPTIONS$/:
					request="OPTIONS";					
				break;
				case /.*CONNECT$/:
					request="CONNECT";					
				break;
				case /.*DELETE$/:
					request="DELETE";					
				break;
				case /.*TRACE$/:
					request="TRACE";					
				break;
				case /.*SECURE$/:
					request="SECURE";
				break;
				case /.*SEARCH$/:
					request="SEARCH";
				break;
				case /.*PROPATCH$/:
					request="PROPATCH";
				break;
				case /.*PROFIND$/:
					request="PROFIND";
				break;
				case /.*MKCOL$/:
					request="MKCOL";
				break;
				
			}
			preParams=_request;
			
		}
		#Split the URL into uriPath and Parameters
		split(arr2ndFld[2],url,"?");
		uriPath=url[1];
		#parse uri path to extract domain, page, and extension
		if(uriPath != "") {
			if(uriPath == "/"){
				domain="/";
				page="NA";
				ext="NA";
			} else {
				split(uriPath,arrUriPath,"/");
				if(arrUriPath[2] ~ /.*\..*/){
					domain="/";
					page=arrUriPath[2];
					split(page,arrPage,".");
					ext=arrPage[2];						
				} else {
					domain=arrUriPath[2];
					page=arrUriPath[length(arrUriPath)];
					split(page,arrPage,".");
					
					if(length(arrPage) > 0){
						ext=arrPage[length(arrPage)];
					} else {
						ext="NA";
					}
				}
			}
		} else {
			domain="NA";
			page="NA";
			ext="NA";
		}
		# create domain array
		arrDmnLst[domain];
		params=url[2];
		if(preParams != ""){
			if(params != "")
				params=params"&"preParams;
			else
				params=preParams;
		}
		protocol=arr2ndFld[3];
		
		#---Process 3rd field
		#302 20 JSESSIONID="-
		#200 28075 JSESSIONID="00006zV1pGhZFY7Gg2P1nzrkjyd:19758rty4
		fld3=$3;
		# Tokenize 3rd field
		split(fld3,arr3rdFld," ");
		# response code
		response=arr3rdFld[1];
		# Response size to client in bytes
		size=arr3rdFld[2];
		#remove 'JSESSIONID=\"' as it is not necessary.
		gsub(/JSESSIONID=\"/,"",arr3rdFld[3]);
		if(arr3rdFld[3] != "-"){
			split(arr3rdFld[3],arrSess,":");
			# remove '0000' prefix from jsession as it is useless
			jsession=substr(arrSess[1],5);
			cloneID=arrSess[2];
			was=arrWasCloneIDs[cloneID];
		} else {
			jsession="-";
			cloneID="-";
			was="-";
		}
		#print arr3rdFld[3],jsessStr,jsession,cloneID
		
		#---Process 4th field
		#UID="abc.def@xyz.com
		fld4=$4;
		#Remove first 5 character (i.e. UID=\") to retrieve UID
		uid=substr(fld4,6);
			
		#---Process 5th field
		#46954 2474 6210
		fld5=$5;
		split(fld5,arrFld5," ");
		# get response time and convert micro second to second
		respTime=arrFld5[1]/1000000
		# Byte Received
		byteRcvd=arrFld5[2];
		# Bytes sent
		byteSnt=arrFld5[3];
		# determine response range
		if(respTime <= 1) {
			respRange = arrRangeName[1];
		} else {
			if(respTime <= 5) {
				respRange = arrRangeName[2];
			} else {
				if(respTime <= 10) {
					respRange = arrRangeName[3]
				} else{
					if(respTime <= 20) {
						respRange = arrRangeName[4];
					} else {
						respRange = arrRangeName[5];
					}
				}
			}
		}
					
		#---Process 6th field
		# Mapping of Windows NT to Actual Windows OS:
		# https://en.wikipedia.org/wiki/List_of_Microsoft_Windows_versions
		# https://msdn.microsoft.com/en-us/library/ms537503(v=vs.85).aspx
		# User agent: https://msdn.microsoft.com/en-us/library/hh869301(v=vs.85).aspx
		#Mozilla/5.0 (Windows NT 6.1; WOW64; rv:38.0) Gecko/20100101 Firefox/38.0
		#"Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.107 Safari/537.36"
		#"Mozilla/5.0 (iPad; CPU OS 8_1_2 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B440 Safari/600.1.4"
		#"Mozilla/5.0 (iPhone; CPU iPhone OS 7_0 like Mac OS X) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11A465 Safari/9537.53 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)"
		#"Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; rv:11.0) like Gecko" - IE11
		#"Mozilla/5.0 (Windows NT 6.3; WOW64; Trident/7.0; Touch; rv:11.0) like Gecko"
		#"Mozilla/5.0 (Windows NT 6.1; Win64; x64; Trident/7.0; rv:11.0) like Gecko"
		#"Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko"
		#"Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0)"
		#"Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; WOW64; Trident/5.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E; InfoPath.3)"
		#"Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Win64; x64; Trident/4.0; .NET CLR 2.0.50727;SLCC2; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E; CMDTDFJS; InfoPath.3)"
		#Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.135 Safari/537.36 Edge/12.<OS build number>
		fld6=$6;
		split(fld6,arrUAgnt," ");
		uAgntArrSize=length(arrUAgnt);
		osName="";
		osFlav="";
		osVer="";
		name="";
		mode="";
		rev="";
		trident="";
		browser="";
		switch(fld6){
			case /.*X11.*Linux.*/:
				#"Mozilla/5.0 (X11; Linux x86_64; rv:10.0) Gecko/20150101 Firefox/47.0 (Chrome)"
				browser=arrUAgnt[uAgntArrSize-1];
				osName=arrUAgnt[3]"/"substr(arrUAgnt[4],1,length(arrUAgnt[4])-1);
				osFlav=substr(arrUAgnt[2],2,length(arrUAgnt[2])-2);
				osVer=substr(arrUAgnt[5],4,length(arrUAgnt[5])-4);
				#print "browser:"browser";osName:"osName";osFlav:"osFlav";osVer:"osVer;
			break;
			case /.*Firefox.*/:
				browser=arrUAgnt[uAgntArrSize];
				osName=substr(arrUAgnt[2],2,length(arrUAgnt[2]));
				osFlav=arrUAgnt[3];
				osVer=substr(arrUAgnt[4],1,length(arrUAgnt[4])-1);								
			break;
			case /Mozilla\/[0-9]+\.[0-9]+ \(compatible; MSIE [0-9]+\.[0-9]+; Windows NT [0-9]+\.[0-9]+; Trident\/.*\)/:
				mode=substr(arrUAgnt[2],2,length(arrUAgnt[2])-2);
				trident=substr(arrUAgnt[8],1,length(arrUAgnt[8])-1);
				rev=substr(arrUAgnt[4],1,length(arrUAgnt[4])-1);
				name=arrUAgnt[3];
				browser=name"/"rev";"mode";"trident;
				osName=arrUAgnt[5];
				osFlav=arrUAgnt[6];
				osVer=substr(arrUAgnt[7],1,length(arrUAgnt[7])-1);	
			break;
			case /Mozilla\/[0-9]+\.[0-9]+ \(Windows NT [0-9]+\.[0-9]+; WOW64; Trident\/[0-9]+\.[0-9]+; rv:[0-9]+\.[0-9]+\) like Gecko/:
				trident=substr(arrUAgnt[6],1,length(arrUAgnt[6])-1);
				rev=substr(arrUAgnt[7],4,length(arrUAgnt[7])-4);
				name="MSIE";
				browser=name"/"rev";"trident;
				osName=substr(arrUAgnt[2],2,length(arrUAgnt[2]));
				osFlav=arrUAgnt[3];
				osVer=substr(arrUAgnt[4],1,length(arrUAgnt[4])-1);
			break;
			case /Mozilla\/[0-9]+\.[0-9]+ \(Windows NT [0-9]+\.[0-9]+; WOW64; Trident\/[0-9]+\.[0-9]+; .*; rv:[0-9]+\.[0-9]+\) like Gecko/:
				trident=substr(arrUAgnt[6],1,length(arrUAgnt[6])-1);
				rev=substr(arrUAgnt[8],4,length(arrUAgnt[8])-4);
				name="MSIE";
				browser=name"/"rev";"trident;
				osName=substr(arrUAgnt[2],2,length(arrUAgnt[2]));
				osFlav=arrUAgnt[3];
				osVer=substr(arrUAgnt[4],1,length(arrUAgnt[4])-1);
			break;
			case /Mozilla\/[0-9]+\.[0-9]+ \(Windows NT [0-9]+\.[0-9]+; Win64; x64; Trident\/[0-9]+\.[0-9]+; .*; rv:[0-9]+\.[0-9]+\) like Gecko/:
				trident=substr(arrUAgnt[7],1,length(arrUAgnt[7])-1);
				rev=substr(arrUAgnt[9],4,length(arrUAgnt[9])-4);
				name="MSIE";
				browser=name"/"rev";"trident;
				osName=substr(arrUAgnt[2],2,length(arrUAgnt[2]));
				osFlav=arrUAgnt[3];
				osVer=substr(arrUAgnt[4],1,length(arrUAgnt[4])-1);
			break;
			case /Mozilla\/[0-9]+\.[0-9]+ \(Windows NT [0-9]+\.[0-9]+; Win64; x64; Trident\/[0-9]+\.[0-9]+; rv:[0-9]+\.[0-9]+\) like Gecko/:
				trident=substr(arrUAgnt[7],1,length(arrUAgnt[7])-1);
				rev=substr(arrUAgnt[8],4,length(arrUAgnt[8])-4);
				name="MSIE";
				browser=name"/"rev";"trident;
				osName=substr(arrUAgnt[2],2,length(arrUAgnt[2]));
				osFlav=arrUAgnt[3];
				osVer=substr(arrUAgnt[4],1,length(arrUAgnt[4])-1);
			break;
			case /Mozilla\/[0-9]+\.[0-9]+ \(Windows NT [0-9]+\.[0-9]+; Trident\/[0-9]+\.[0-9]+; rv:[0-9]+\.[0-9]+\) like Gecko/:
				trident=substr(arrUAgnt[5],1,length(arrUAgnt[5])-1);
				rev=substr(arrUAgnt[6],4,length(arrUAgnt[6])-4);
				name="MSIE";
				browser=name"/"rev";"trident;
				osName=substr(arrUAgnt[2],2,length(arrUAgnt[2]));
				osFlav=arrUAgnt[3];
				osVer=substr(arrUAgnt[4],1,length(arrUAgnt[4])-1);
			break;
			case /Mozilla\/[0-9]+\.[0-9]+ \(compatible; MSIE [0-9]+\.[0-9]+; Windows NT [0-9]+\.[0-9]+; WOW64; Trident\/.*\)/:
				mode=substr(arrUAgnt[2],2,length(arrUAgnt[2])-2);
				rev=substr(arrUAgnt[4],1,length(arrUAgnt[4])-1)
				trident=substr(arrUAgnt[9],1,length(arrUAgnt[9])-1);
				name=arrUAgnt[3];
				browser=name"/"rev";"mode";"trident;
				osName=arrUAgnt[5];
				osFlav=arrUAgnt[6];
				osVer=substr(arrUAgnt[7],1,length(arrUAgnt[7])-1);
			break;
			case /Mozilla\/[0-9]+\.[0-9]+ \(compatible; MSIE [0-9]+\.[0-9]+; Windows NT [0-9]+\.[0-9]+; Win64; x64; Trident\/.*\)/:
				mode=substr(arrUAgnt[2],2,length(arrUAgnt[2])-2);
				trident=substr(arrUAgnt[10],1,length(arrUAgnt[10])-1);
				rev=substr(arrUAgnt[4],1,length(arrUAgnt[4])-1);
				name=arrUAgnt[3];
				browser=name"/"rev";"mode";"trident;
				osName=arrUAgnt[5];
				osFlav=arrUAgnt[6];
				osVer=substr(arrUAgnt[7],1,length(arrUAgnt[7])-1);
			break;
			case /Mozilla\/[0-9]+\.[0-9]+ \(compatible; MSIE [0-9]+\.[0-9]+; Windows NT [0-9]+\.[0-9]+.*\)/:
				mode=substr(arrUAgnt[2],2,length(arrUAgnt[2])-2);
				trident="";
				rev=substr(arrUAgnt[4],1,length(arrUAgnt[4])-1);
				name=arrUAgnt[3];
				browser=name"/"rev";"mode;
				osName=arrUAgnt[5];
				osFlav=arrUAgnt[6];
				osVer=substr(arrUAgnt[7],1,length(arrUAgnt[7])-1);
			break;
			case /.*Edge\/[0-9]+\..*/:
				browser=arrUAgnt[uAgntArrSize];
				osName=substr(arrUAgnt[2],2,length(arrUAgnt[2]));
				osFlav=arrUAgnt[3];
				osVer=substr(arrUAgnt[4],1,length(arrUAgnt[4])-1);
			break;
			case /.*iPad.*AppleWebKit\/.*\(KHTML, like Gecko\) .*Safari\/.*/:
				#"Mozilla/5.0 (iPad; CPU OS 8_1_2 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B440 Safari/600.1.4"
				#"Mozilla/5.0 (iPad; CPU OS 10_0_2 like Mac OS X) AppleWebKit/602.1.50 (KHTML, like Gecko) CriOS/58.0.3029.83 Mobile/14A456 Safari/602.1"
				browser=arrUAgnt[uAgntArrSize-1]"/"arrUAgnt[uAgntArrSize];
				osName=substr(arrUAgnt[2],2,length(arrUAgnt[2])-2);
				osFlav=arrUAgnt[6]" "arrUAgnt[7]" "arrUAgnt[8]" "substr(arrUAgnt[9],1,length(arrUAgnt[9])-1);
				osVer=arrUAgnt[5];
			break;
			case /.*iPhone.*AppleWebKit\/.*\(KHTML, like Gecko\) [^Chrome].*Safari\/.*/:
				#"Mozilla/5.0 (iPhone; CPU iPhone OS 7_0 like Mac OS X) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11A465 Safari/9537.53 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)"
				browser=arrUAgnt[17];
				osName=substr(arrUAgnt[2],2,length(arrUAgnt[2])-2);
				osFlav=arrUAgnt[7]" "arrUAgnt[8]" "arrUAgnt[9]" "substr(arrUAgnt[10],1,length(arrUAgnt[10])-1);
				osVer=arrUAgnt[6];
			break;
			case /.*Linux.*Android.*AppleWebKit\/.*\(KHTML, like Gecko\) [Chrome].*Safari\/.*/:
				#"Mozilla/5.0 (Linux; Android 5.0; SM-G900W8 Build/LRX21T) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.98 Mobile Safari/537.36"
				browser=arrUAgnt[uAgntArrSize-2]"/"arrUAgnt[uAgntArrSize-1]"/"arrUAgnt[uAgntArrSize];
				osName=substr(arrUAgnt[2],2,length(arrUAgnt[2])-2);
				osFlav=arrUAgnt[3];
				osVer=substr(arrUAgnt[4],1,length(arrUAgnt[4])-1);
			break;
			case /.*AppleWebKit\/.*\(KHTML, like Gecko\) [Chrome].*Safari\/.*/:
				#"Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.96 Safari/537.36"
				browser=arrUAgnt[uAgntArrSize-1]"/"arrUAgnt[uAgntArrSize];
				osName=substr(arrUAgnt[2],2,length(arrUAgnt[2]));
				osFlav=arrUAgnt[3];
				osVer=substr(arrUAgnt[4],1,length(arrUAgnt[4])-1);				
			break;			
			default:
				browser="Other";
				osName="Other";
				osFlav="na";
				osVer="na";
				# log the unknown user agent into file for review.
				print $0 >> fTempHttp".unknownua";
			break;
		}
		
		#---Process 7th field
		#srvwebp0bfv050 app_user="abc.def@sysg.com
		split($7,fld7Tok," ");
		#webSrvr=$7
		webSrvr=fld7Tok[1];
				
		
		#print formatted and filtered access log records
		# here is output field mapping, may need later
		# $1:webSrvr;$2:dt;$3:tm;$4:tz;$5:hour;$6:jsession;$7:cloneID;$8:was;$9:domain;$10:page;$11:ext;$12:uriPath;$13:params;$14:protocol;$15:request
		# $16:response;$17:size;$18:byteRcvd;$19:byteSnt;$20:uid;$21:respTime;$22:respRange;$23:browser;$24:osName;$25:osFlav;$26:osVer.
		print webSrvr,dt,tm,tz,hour,jsession,cloneID,was,domain,page,ext,uriPath,params,protocol,request,response,size,byteRcvd,byteSnt,uid,respTime,respRange,browser,osName,osFlav,osVer >> fTempHttp".access_log_all";
		# Create separate array of transaction that has response code greater than or equal to 400 and also print them in separate file.
		if(response >= 400){
			arrUri400plsUriRange[uriPath"|"response]++;
		}
		#Gather some request stats for monthly reporting
		arrByHstByRqst[webSrvr"|"request]++;
		arrByHstByRsp[webSrvr"|"response]++;
		arrWebSrv[webSrvr];
		
		# discard certain records and write them into separate file for review.
		# request comming from Curl, 'curl'
		# request not having UID, i.e. UID="-"
		if (fld6 ~ /curl\/*/ || uid == "-" || uid ==""){
			discRecCnt++;
			#print the discarded record in separate file for later review
			print webSrvr,dt,tm,tz,hour,jsession,cloneID,was,domain,page,ext,uriPath,params,protocol,request,response,size,byteRcvd,byteSnt,uid,respTime,respRange,browser,osName,osFlav,osVer >> fTempHttp".discarded";
		} else {
			rcdCntIncl++;
			# daily unique users
			arrDlyuUid[uid];
			# hourly unique users
			arrHrlUUid[hour","uid];
			if(uid != "" && uid != "-"){
				# daily unique users by domain
				arrDlyuUidDmn[uid","domain];				
				# hourly unique users by domain
				arrHrlUUidDmn[hour","uid","domain];
				arrWebUid[webSrvr"|"uid];
				if(cloneID != "" && cloneID != "-") 
					arrWasUid[was","cloneID","uid];
			}
			
			if(jsession != "" && jsession != "-"){
				arrHrljSess[hour","jsession]=uid;
				# hourly jSesion by Domain
				arrHrljSessDmn[hour","jsession","domain];
				#daily unique jSession;
				arrDlyjSess[cloneID","jsession];
				#daily unique jSession by Domain
				arrDlyjSessDmn[cloneID","jsession","domain];
				#jSession count by web server. 
				#Note: since there is possibility that two AppServer may generate same jsession and when
				#finding unique session at Web Server, these two may be considered as one, so use cloneID in combination.
				arrWebHostjSess[webSrvr","jsession","cloneID];
				#jSession count by WAS
				arrWasjSess[was","cloneID","jsession];
				#where the user is in particular momenet:
				if(uriPath == "/SecurityWeb/roleSelect/loginRoleSelect.xhtml"){
					arrWhereUidStart[webSrvr" "was" "cloneID" "jsession" "uid]=dt":"tm" "tmInSec;
				}
				if(uriPath == "/SecurityWeb/Portal" && params ~ /logout=true/){
					arrWhereUidEnd[webSrvr" "was" "cloneID" "jsession" "uid]=dt":"tm" "tmInSec;
				}
			}
			#Count by http response code
			arrRespCnt[response]++;
			# Array for uri range
			arrURIRange[uriPath","respRange]++;	
			arrURITimeSum[uriPath]+=respTime;
			arrURICnt[uriPath]++
					
			#Hourly record count - including static content
			arrHrlyRcdCntIncl[hour]++;
			# Summarize by extension
			arrExtRange[ext","respRange]++;
			arrExtCnt[ext]++;
			arrExtRspTmSum[ext]+=respTime;
			arrBrwsr[browser","uid];
			arrOS[osName","osFlav","osVer","uid];
			# request count by Web Server - including static content
			arrReqCntByWSIncl[webSrvr]++;
			arrReqCntByWASIncl[was","cloneID]++;
			# Exclude static content for the following calculation
			# hourly response range
			if(response != "304" && ext !~ /(^jpg$|^gif$|^png$|^ico$|^js$|^cgi$|^css$|^htm$|^html$|^pdf$|^null$|^doc$|^xlsx$|^xsl$|^aspx$|^txt$)/ && uriPath !~ /(.*\.css\.xhtml$|.*\.js\.xhtml$|.*\.png\.xhtml$|.*\.gif\.xhtml$)/ && params !~ /(WilyCmd=cmdJS|WilyCmd=cmdMetrics)/){
				#Daily Record count - excluding static contents
				rcdCntXcl++;
				#Hourly record count - excluding static content
				arrHrlyRcdCntXcl[hour]++;
				#Hourly range
				arrHrlRange[hour","respRange]++;
				#Hourly Sum of response time
				arrHrlyRspTimeSum[hour]+=respTime;
				#Damily Response time sum
				dlyRespTimeSum+=respTime;
				#Daily range
				arrDlyRange[respRange]++;
				#arrDmnRange[domain","respRange]++;
				arrDmnSum[domain]+=respTime;
				arrDmnCnt[domain]++;
				arrUidRange[uid","respRange]++;
				arrUidSum[uid]+=respTime;
				arrUidCnt[uid]++;
				# stats by Web and App server
				arrReqCntByWSXcl[webSrvr]++;
				arrReqCntByWASXcl[was","cloneID]++;
				# range
				arrRngByWS[webSrvr","respRange]++;
				arrRngByWAS[was","cloneID","respRange]++;
				# perf
				arrPerfByWS[webSrvr]+=respTime;
				arrPerfByWAS[was","cloneID]+=respTime;
				# record min and max time for the transaction
				min=max=respTime;
				uriMnMxStr=arrURIMnMx[uriPath];
				if(uriMnMxStr != ""){
					split(uriMnMxStr,uriMnMxStrTok,"|");
					min=uriMnMxStrTok[1];
					max=uriMnMxStrTok[2];
					if(respTime > max){
						max=respTime;
						arrURIMnMx[uriPath]=min"|"max;
					} else {
						if(respTime < min){
							min=respTime;
							arrURIMnMx[uriPath]=min"|"max;
						}
					}
				} else {
					arrURIMnMx[uriPath]=min"|"max;
				}
			}
		}			
		
	} END {
		# print request type and response code matrics by server.
		if(rptType == "daily"){
		    #DO NOT CHANGE THE SEQUENCE
			reqLst="GET|POST|PUT|HEAD|OPTIONS|CONNECT|DELETE|TRACE|PROFIND|SEARCH|PROPATCH|SECURE|MKCOL";
			split(reqLst,arrReqLst,"|");
			#DO NOT CHANGE THE SEQUENCE
			rspLst="100|101|102|103|200|201|202|203|204|205|206|207|208|226|300|301|302|303|304|305|306|307|308|400|401|402|403|404|405|406|407|408|409|410|411|412|413|414|415|416|417|418|419|420|421|422|423|424|426|428|429|431|440|444|449|450|451|495|496|497|498|499|500|501|502|503|504|505|506|507|508|509|510|511|520|521|523|524|525|526";
			split(rspLst,arrRspLst,"|");
			reqStr="";
			if(length(arrByHstByRqst) >0){
				for(eWS in arrWebSrv){
					eWSReqStr="";
					for(reqIdx in arrReqLst){
						_val=arrByHstByRqst[eWS"|"arrReqLst[reqIdx]];
						
						if(_val == "")
							_val = 0;
						if(length(eWSReqStr) > 0)
							eWSReqStr=eWSReqStr"|"_val;
						else
							eWSReqStr=_val;
					}
					
					eWSReqStr=recDate"|"eWS"|"eWSReqStr;
					if(length(reqStr) > 0)
						reqStr=reqStr"\n"eWSReqStr;
					else
						reqStr=eWSReqStr;
					
				}
				print reqStr >> rptRqstTypeByHostHistFile;
			}
			
			if(length(arrByHstByRsp) > 0){
				rspStr="";
				for(eWS in arrWebSrv){
					eWSRspStr="";
					for(eRspIdx in arrRspLst){
						_val=arrByHstByRsp[eWS"|"arrRspLst[eRspIdx]];
						if(_val == "")
							_val = 0;
						if(length(eWSRspStr) > 0)
							eWSRspStr=eWSRspStr"|"_val;
						else
							eWSRspStr=_val;
					}
					eWSRspStr=recDate"|"eWS"|"eWSRspStr;
					if(length(rspStr) > 0)
						rspStr=rspStr"\n"eWSRspStr;
					else
						rspStr=eWSRspStr;
				}
				print rspStr >> rptRspByCodeHistFile;				
			}
		}
		# print roaming user
		if(length(arrRoamUid) > 0){
			for(eRuid in arrRoamUid){
				print eRuid >> fTempHttp".ruid";
			}
		}
		# print number of discarded records in summary file.
		print "Number of discarded records : "discRecCnt >> fTempHttp".summary";
		# Create alert if number of discarded records is higher than certain threshold
		if(discRecCnt > arrTh["httpDiscRcdCountTh"]){
			print discRecCnt" : total number of discarded record counts exceeds threshold of : "arrTh["httpDiscRcdCountTh"]". Review "rptDiscardedRecordsFile >> alrtF;
		}
		# Print hourly statistics
		print "" >> fTempHttp".summary";
		print "" >> fTempHttp".summary";
		print "=====================================================" >> fTempHttp".summary";
		print "===== Hourly Statistics =====" >> fTempHttp".summary";
		print "Note: Hourly statistics excludes the following static contents from calculation:" >> fTempHttp".summary";
		print "excludes with these extensions: jpg|gif|png|ico|js|cgi|css|htm|html|pdf|null|doc|xlsx|xsl|aspx|txt|.css.xhtml|.js.xhtml|.png.xhtml|.gif.xhtml" >> fTempHttp".summary";
		print "=====================================================" >> fTempHttp".summary";
		print "" >> fTempHttp".summary";
		hrlHdFmt="%-3s\t%5s\t%5s\t%7s\t%7s\t%7s\t%7s\t%7s\t%7s\t%8s\t%8s\n";
		hrlBdFmt="%-3d\t%5d\t%5d\t%7.3f\t%7.3f\t%7.3f\t%7.3f\t%7.3f\t%7.3f\t%8d\t%8d\n";
		printf hrlHdFmt,"hr","uuc","usc","art",arrRangeName[1],arrRangeName[2],arrRangeName[3],arrRangeName[4],arrRangeName[5],"xrc","irc" >> fTempHttp".summary";
		#for hourly average history file
		tmpHrlyAvgStr=""recDate;
		tmpHrlyuUidStr=""recDate;
		for (i=0; i < 24; i++){
			if(i<10){
				j=0i;
			} else {
				j=i;
			}
			
			hrUidCnt[j]=0;
			for(hduid in arrHrlUUid){
				split(hduid,hr,",");
				if(j == hr[1]){
					hrUidCnt[j]++;
				}
			}
			hrjSessCnt[j]=0;
			for(hdjSess in arrHrljSess){
				split(hdjSess,hs,",");
				if(j == hs[1]){
					hrjSessCnt[j]++;
				}
			}
			hrlyAvgRespTime="";
			if(arrHrlyRcdCntXcl[j] > 0){
				hrlyAvgRespTime=arrHrlyRspTimeSum[j]/arrHrlyRcdCntXcl[j];
			}
			tmpHrlyuUidStr=tmpHrlyuUidStr"|"hrUidCnt[j];
			tmpHrlyAvgStr=tmpHrlyAvgStr"|"hrlyAvgRespTime;
			#hrlyRowTtl=arrHrlRange[j","arrRangeName[1]]+arrHrlRange[j","arrRangeName[2]]+arrHrlRange[j","arrRangeName[3]]+arrHrlRange[j","arrRangeName[4]]+arrHrlRange[j","arrRangeName[5]];
			if(arrHrlyRcdCntXcl[j] > 0){
				hrlPc=100/arrHrlyRcdCntXcl[j];
			} else {
				hrlPc="";
			}
			if(hrUidCnt[j] > 0) {
				printf hrlBdFmt, j, hrUidCnt[j],hrjSessCnt[j], hrlyAvgRespTime, arrHrlRange[j","arrRangeName[1]]*hrlPc, arrHrlRange[j","arrRangeName[2]]*hrlPc, arrHrlRange[j","arrRangeName[3]]*hrlPc, arrHrlRange[j","arrRangeName[4]]*hrlPc, arrHrlRange[j","arrRangeName[5]]*hrlPc,arrHrlyRcdCntXcl[j],arrHrlyRcdCntIncl[j] >> fTempHttp".summary";
			}
			# Alert if average response time is higher than threshold
			if(hrlyAvgRespTime > arrTh["httpAvgRespTimeTh"]) {
				print "Average response time: "hrlyAvgRespTime " : for hour: "j" exceeds threshold value: "arrTh["httpAvgRespTimeTh"]". Investigate further ..." >> alrtF;
			}
			#hourly domain count by unique user
			for(eDmn in arrDmnLst){
				arrHrlDmnByUuid[j","eDmn];
				arrHrlDmnBySess[j","eDmn];
				for(eRec in arrHrlUUidDmn){
					split(eRec,arrRecUUidDmn,",");
					if(arrRecUUidDmn[1] == j && arrRecUUidDmn[3] == eDmn){
						arrHrlDmnByUuid[arrRecUUidDmn[1]","eDmn]++;
					}
				}
				
				for(eRec in arrHrljSessDmn){
					split(eRec,arrRecSessDmn,",");
					
					if(arrRecSessDmn[1] == j && arrRecSessDmn[3] == eDmn){
						arrHrlDmnBySess[arrRecSessDmn[1]","eDmn]++;
					}
				}
				
			}
		}
		#print the hourly average in hourly average history file
		if(rptType == "daily"){
			print tmpHrlyAvgStr >> rptHrlyAvgHistFile;
			print tmpHrlyuUidStr >> rptUnqUsrHrlyHistFile;
		}
		
		#print daily range
		#dlyRowTtl=arrDlyRange[arrRangeName[1]]+arrDlyRange[arrRangeName[2]]+arrDlyRange[arrRangeName[3]]+arrDlyRange[arrRangeName[4]]+arrDlyRange[arrRangeName[5]];
		if(rcdCntXcl > 0){
			dlyPc=100/rcdCntXcl;
		} else {
			dlyPc=0;
		}
		# Calculate daily average - excludes the static contents
		dlyAvgRespTime=0;
		if(rcdCntXcl > 0){
			dlyAvgRespTime=dlyRespTimeSum/rcdCntXcl;
		}
		#print rcdCntXcl,dlyAvgRespTime,arrDlyRange[arrRangeName[1]]*dlyPc, arrDlyRange[arrRangeName[2]]*dlyPc, arrDlyRange[arrRangeName[3]]*dlyPc, arrDlyRange[arrRangeName[4]]*dlyPc, arrDlyRange[arrRangeName[5]]*dlyPc;
		# Alert logic for daily average and range
		if(length(arrTh) > 0 ){
			# Alert for Average response time
			if(arrTh["httpAvgRespTimeTh"] != "" && dlyAvgRespTime != "" && dlyAvgRespTime > arrTh["httpAvgRespTimeTh"]){
				print "Overall average response time: "dlyAvgRespTime " : exceeds the threshold value of "arrTh["httpAvgRespTimeTh"]". Investigate further ..." >> alrtF;
			}
			
			# Alert for range percentage
			if(arrTh["httpDly1SecRangeTh"] != "" && arrDlyRange[arrRangeName[1]]*dlyPc < arrTh["httpDly1SecRangeTh"]){
				print arrDlyRange[arrRangeName[1]]*dlyPc "% in 1 sec range is less than expected threshold value of "arrTh["httpDly1SecRangeTh"]"%. Investigate further ..." >> alrtF;
			}
			if(arrTh["httpDly20SecRangeTh"] != "" && arrDlyRange[arrRangeName[5]]*dlyPc > arrTh["httpDly20SecRangeTh"]){
				print arrDlyRange[arrRangeName[5]]*dlyPc "% in 20 sec or higher range is more than threshold value of "arrTh["httpDly20SecRangeTh"]"%. Investigate further ..." >> alrtF;
			}
		}		
		
		# summary by UID
		for(eachUid in arrUidCnt){
			avgRspTimeByUid="";
			if(arrUidCnt[eachUid] > 0){
				avgRspTimeByUid=arrUidSum[eachUid]/arrUidCnt[eachUid];
				uidRngPc=100/arrUidCnt[eachUid];
			}
			#Print into separate file as it may have few hundred lines. Later on top 10 users can be printed into summary file.
			print eachUid,arrUidRange[eachUid","arrRangeName[1]]*uidRngPc,arrUidRange[eachUid","arrRangeName[2]]*uidRngPc,arrUidRange[eachUid","arrRangeName[3]]*uidRngPc,arrUidRange[eachUid","arrRangeName[4]]*uidRngPc,arrUidRange[eachUid","arrRangeName[5]]*uidRngPc,arrUidCnt[eachUid],avgRspTimeByUid >> fTempHttp".byuid"
			
		}
		
		#Print the daily summary into history file
		if(rptType == "daily"){
			print recDate,length(arrUidCnt),length(arrDlyjSess),arrDlyRange[arrRangeName[1]]*dlyPc, arrDlyRange[arrRangeName[2]]*dlyPc, arrDlyRange[arrRangeName[3]]*dlyPc, arrDlyRange[arrRangeName[4]]*dlyPc, arrDlyRange[arrRangeName[5]]*dlyPc,dlyAvgRespTime,rcdCntXcl,rcdCntIncl >> rptPerfHistFile;
		}
		#print daily summary also in summary file.
		print "" >> fTempHttp".summary";
		print "" >> fTempHttp".summary";
		print "=====================================================" >> fTempHttp".summary";
		print "===== Overall-Daily Statistics =====" >> fTempHttp".summary";
		print "Note: Overall response range and average response time excludes the following static contents from calculation:" >> fTempHttp".summary";
		print "excludes with these extensions: jpg|gif|png|ico|js|cgi|css|htm|html|pdf|null|doc|xlsx|xsl|aspx|txt|.css.xhtml|.js.xhtml|.png.xhtml|.gif.xhtml" >> fTempHttp".summary";
		print "=====================================================" >> fTempHttp".summary";
		print "" >> fTempHttp".summary";
		dlyHdFmt="%-10s\t%5s\t%5s\t%7s\t%7s\t%7s\t%7s\t%7s\t%7s\t%8s\t%8s\n";
		dlyBdFmt="%10s\t%5d\t%5d\t%7.3f\t%7.3f\t%7.3f\t%7.3f\t%7.3f\t%7.3f\t%8d\t%8d\n";
		printf dlyHdFmt,"date","uuc","usc","art",arrRangeName[1],arrRangeName[2],arrRangeName[3],arrRangeName[4],arrRangeName[5],"xrc","irc" >> fTempHttp".summary";
		printf dlyBdFmt,recDate,length(arrUidCnt),length(arrDlyjSess),dlyAvgRespTime,arrDlyRange[arrRangeName[1]]*dlyPc, arrDlyRange[arrRangeName[2]]*dlyPc, arrDlyRange[arrRangeName[3]]*dlyPc, arrDlyRange[arrRangeName[4]]*dlyPc, arrDlyRange[arrRangeName[5]]*dlyPc,rcdCntXcl, rcdCntIncl >> fTempHttp".summary"
		
		#summarize by URI
		for(eachUri in arrURIMnMx){
			#arrBaseLine
			#uriRngRowTtl=arrURIRange[eachUri","arrRangeName[1]]+arrURIRange[eachUri","arrRangeName[2]]+arrURIRange[eachUri","arrRangeName[3]]+arrURIRange[eachUri","arrRangeName[4]]+arrURIRange[eachUri","arrRangeName[5]];
			if(arrURICnt[eachUri] > 0){
				avgRspTimeByUri=arrURITimeSum[eachUri]/arrURICnt[eachUri]
				#uriRngPc=100/uriRngRowTtl;
				uriRngPc=100/arrURICnt[eachUri];
				# Get baseline performance
				avgBslnRspTimeByUri=arrBaseLine[eachUri];
				if(avgBslnRspTimeByUri != ""){
					diffRspTimeByUri=avgRspTimeByUri-avgBslnRspTimeByUri;
					deviation=(diffRspTimeByUri/avgBslnRspTimeByUri)*100;
				} else {
					diffRspTimeByUri="";
					deviation="";
				}
			} else {
				uriRngPc=0;
			}
			minMaxVal=arrURIMnMx[eachUri];
			print eachUri,arrURIRange[eachUri","arrRangeName[1]]*uriRngPc,arrURIRange[eachUri","arrRangeName[2]]*uriRngPc, arrURIRange[eachUri","arrRangeName[3]]*uriRngPc, arrURIRange[eachUri","arrRangeName[4]]*uriRngPc, arrURIRange[eachUri","arrRangeName[5]]*uriRngPc,arrURICnt[eachUri],avgRspTimeByUri,avgBslnRspTimeByUri,diffRspTimeByUri,minMaxVal >> fTempHttp".uri";
			
		}
		if(length(arrDmnCnt) > 0){
			tmpDmnStr=""recDate;
			for(dmnName in arrDmnLst){
				avgRspTmByDmn="";
				if(arrDmnCnt[dmnName] > 0){
					avgRspTmByDmn=arrDmnSum[dmnName]/arrDmnCnt[dmnName];
					# TBD alert by domain goes here.
					if(arrTh["httpAvgRespTimeTh"] != "" && avgRspTmByDmn != "" && avgRspTmByDmn > arrTh["httpAvgRespTimeTh"]){
						print "Average response time: "avgRspTmByDmn" for domain: "dmnName" exceeds threshold value: "arrTh["httpAvgRespTimeTh"]". Investigate further..." >> alrtF;
					}
					print dmnName,avgRspTmByDmn,arrDmnCnt[dmnName] >> fTempHttp".bydmn"
				}
				tmpDmnStr=tmpDmnStr"|"avgRspTmByDmn;								
			}
			# print int history file.
			#if(rptType == "daily"){
			#	print tmpDmnStr >> rptDomainPerfHistFile;
			#}
		}
		
		
		# print jSession by web server
		for (eachWS in arrWebHostjSess){
			split(eachWS,webjSess,",");
			arrjSessCntByWebSrvr[webjSess[1]]++;
			#print eachWS >> fTempHttp".websess";
			ttlWebjSessCnt++;
		}
		# print uuid by web server
		for (eachWS in arrWebUid){
			split(eachWS,webUuid,"|");
			arrUuidCntByWS[webUuid[1]]++;
			#ttlWSUuidCnt++;
		}
		
		print "" >> fTempHttp".summary";
		print "" >> fTempHttp".summary";
		print "=====================================================" >> fTempHttp".summary";
		print "===== Statistics by Web Server(IHS)  and WebSphere App Server (WAS) =====" >> fTempHttp".summary";
		print "=====================================================" >> fTempHttp".summary";
		print "" >> fTempHttp".summary";
		
		wsHdFmt="%-32s\t%5s\t%5s\t%7s\t%7s\t%7s\t%7s\t%7s\t%7s\t%7s\t%7s\n";
		wsBdFmt="%-32s\t%5d\t%5d\t%7.3f\t%7.3f\t%7.3f\t%7.3f\t%7.3f\t%7.3f\t%7.3f\t%7.3f\n";
		printf wsHdFmt,"srv","uuc","jsc","art",arrRangeName[1],arrRangeName[2],arrRangeName[3],arrRangeName[4],arrRangeName[5],"xrpc","irpc" >> fTempHttp".summary";
		
		if(length(arrReqCntByWSIncl) > 0){
			for(eRCByWSIncl in arrReqCntByWSIncl){
				if(arrReqCntByWSIncl[eRCByWSIncl] > 0){
					rqInclPc=(arrReqCntByWSIncl[eRCByWSIncl]/rcdCntIncl)*100;
					rqXclPc=0;
					if(arrReqCntByWSXcl[eRCByWSIncl] > 0)
						rqXclPc=(arrReqCntByWSXcl[eRCByWSIncl]/rcdCntXcl)*100;
					
					if(arrjSessCntByWebSrvr[eRCByWSIncl] > 0){
						#jsPc=(arrjSessCntByWebSrvr[eRCByWSIncl]/ttlWebjSessCnt)*100;
						jsc=arrjSessCntByWebSrvr[eRCByWSIncl];
					} else {
						#jsPc=0;
						jsc=0;
					}
					if(arrUuidCntByWS[eRCByWSIncl] > 0){
						#uidPc=(arrUuidCntByWS[eRCByWSIncl]/ttlWSUuidCnt)*100;
						uuc=arrUuidCntByWS[eRCByWSIncl]
					} else {
						#uidPc=0;
						uuc=0;
					}
					if(arrReqCntByWSXcl[eRCByWSIncl] > 0){
						_1rng=(arrRngByWS[eRCByWSIncl","arrRangeName[1]]/arrReqCntByWSXcl[eRCByWSIncl])*100;
						_5rng=(arrRngByWS[eRCByWSIncl","arrRangeName[2]]/arrReqCntByWSXcl[eRCByWSIncl])*100;
						_10rng=(arrRngByWS[eRCByWSIncl","arrRangeName[3]]/arrReqCntByWSXcl[eRCByWSIncl])*100;
						_20rng=(arrRngByWS[eRCByWSIncl","arrRangeName[4]]/arrReqCntByWSXcl[eRCByWSIncl])*100;
						_g20rng=(arrRngByWS[eRCByWSIncl","arrRangeName[5]]/arrReqCntByWSXcl[eRCByWSIncl])*100;
					} else {
						_1rng=_5rng=_10rng=_20rng=_g20rng=0;
					}
					printf wsBdFmt,eRCByWSIncl,uuc,jsc,arrPerfByWS[eRCByWSIncl]/arrReqCntByWSXcl[eRCByWSIncl],_1rng,_5rng,_10rng,_20rng,_g20rng,rqXclPc,rqInclPc >> fTempHttp".summary";
					if(rptType == "daily")
						print recDate,eRCByWSIncl,uuc,jsc,arrPerfByWS[eRCByWSIncl]/arrReqCntByWSXcl[eRCByWSIncl],_1rng,_5rng,_10rng,_20rng,_g20rng,rqXclPc,rqInclPc >> rptStatByIHSHistFile;
				}
			}
		}
				
		for(eachWAS in arrWasjSess){
			split(eachWAS,wasJSess,",");
			arrjSessCntByWAS[wasJSess[1]","wasJSess[2]]++;
			ttlWASjSessCnt++;			
		}
		# print uuid by WAS
		for (eWASUid in arrWasUid){
			split(eWASUid,wasUuidTok,",");
			arrUuidCntByWAS[wasUuidTok[1]","wasUuidTok[2]]++;
			#ttlWASUuidCnt++;
		}
		print "" >> fTempHttp".summary";
		if(length(arrReqCntByWASIncl) > 0){
			for(eRCByWASIncl in arrReqCntByWASIncl){
				split(eRCByWASIncl,wasNmTok,",");
				if(wasNmTok[2] != "" && wasNmTok[2] != "-"){
					if(arrReqCntByWASIncl[eRCByWASIncl] > 0){
						if(rcdCntIncl > 0){
							rqInclPc=(arrReqCntByWASIncl[eRCByWASIncl]/rcdCntIncl)*100;
						} else {
							rqInclPc=0;
						}
						if(arrReqCntByWASXcl[eRCByWASIncl] > 0 && rcdCntXcl > 0)
							rqXclPc=(arrReqCntByWASXcl[eRCByWASIncl]/rcdCntXcl)*100;
						else
							rqXclPc=0;
						if(arrjSessCntByWAS[eRCByWASIncl] > 0){
							jsc=arrjSessCntByWAS[eRCByWASIncl];
						} else {
							jsc=0;
						}
						if(arrUuidCntByWAS[eRCByWASIncl] > 0){
							uuc=arrUuidCntByWAS[eRCByWASIncl]
						} else {
							uuc=0;
						}
						if(arrReqCntByWASXcl[eRCByWASIncl] > 0){
							_1rng=(arrRngByWAS[eRCByWASIncl","arrRangeName[1]]/arrReqCntByWASXcl[eRCByWASIncl])*100;
							_5rng=(arrRngByWAS[eRCByWASIncl","arrRangeName[2]]/arrReqCntByWASXcl[eRCByWASIncl])*100;
							_10rng=(arrRngByWAS[eRCByWASIncl","arrRangeName[3]]/arrReqCntByWASXcl[eRCByWASIncl])*100;
							_20rng=(arrRngByWAS[eRCByWASIncl","arrRangeName[4]]/arrReqCntByWASXcl[eRCByWASIncl])*100;
							_g20rng=(arrRngByWAS[eRCByWASIncl","arrRangeName[5]]/arrReqCntByWASXcl[eRCByWASIncl])*100;
							ewasart=arrPerfByWAS[eRCByWASIncl]/arrReqCntByWASXcl[eRCByWASIncl];
						} else {
							_1rng=_5rng=_10rng=_20rng=_g20rng=0;
							ewasart=arrPerfByWAS[eRCByWASIncl];
						}
						printf wsBdFmt,wasNmTok[1]":"wasNmTok[2],uuc,jsc,ewasart,_1rng,_5rng,_10rng,_20rng,_g20rng,rqXclPc,rqInclPc >> fTempHttp".summary";
						if(rptType == "daily")
							print recDate,wasNmTok[1]":"wasNmTok[2],uuc,jsc,ewasart,_1rng,_5rng,_10rng,_20rng,_g20rng,rqXclPc,rqInclPc >> rptStatByWASHistFile;
					}
				}
			}
		}
		
		if(length(arrRespCnt) >0){
			#print summary by response code
			print "" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "===== Statistics by HTTP response code =====" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			
			rcHdFmt="%-3s\t%11s\t%7s\n";
			rcBdFmt="%-3d\t%11d\t%7.3f\n";
			printf rcHdFmt,"rsp","cnt","pc","irc" >> fTempHttp".summary";
			for(rspCode in arrRespCnt){
				if(arrRespCnt[rspCode] > 0 && rcdCntIncl > 0){
					pcCntByRsp=(100*arrRespCnt[rspCode])/rcdCntIncl;
					if(rspCode >= 400){
						rsp400Pls+=pcCntByRsp;
					}
					printf rcBdFmt,rspCode,arrRespCnt[rspCode],pcCntByRsp >> fTempHttp".summary";
				}
			}
			print "Total response count: "rcdCntIncl >> fTempHttp".summary";
			
			if(arrTh["http400PlusRespCountTh"] != "" && rsp400Pls != "" && rsp400Pls > arrTh["http400PlusRespCountTh"]){
				#put some alert here if percentage of 400+ response code exceeds some percentile threshold.
				print "Total percentage of http response code 400 and higher: "rsp400Pls" exceeds threshold of " arrTh["http400PlusRespCountTh"] ". Investigate further ..." >> alrtF;
			}
			if(length(arrUri400plsUriRange) > 0){
				for(each400Pls in arrUri400plsUriRange) {
					split(each400Pls,arr4p,"|");
					ttl400PlusByUri=arrUri400plsUriRange[each400Pls];
					print arr4p[1],arr4p[2],ttl400PlusByUri >> fTempHttp".sumby400plsuri";								
				}
			}
		}
		
		# summary by browser
		for (eub in arrBrwsr){
			split(eub,arrUBLst,",");
			arrUBrwsrCnt[arrUBLst[1]]++;				
		}
		
		for(eb in arrUBrwsrCnt){
			print eb,arrUBrwsrCnt[eb],arrUBrwsrCnt[eb]*(100/length(arrBrwsr)) >> fTempHttp".sumbybrwsr";
		}
		# summary by OS agent
		for (eUOS in arrOS){
			split(eUOS,arrUOSLst,",");
			arrOSCnt[arrUOSLst[1]"/"arrUOSLst[2]"/"arrUOSLst[3]]++;
		}
		for(eOS in arrOSCnt){
			print eOS,arrOSCnt[eOS],arrOSCnt[eOS]*(100/length(arrOS))>> fTempHttp".sumbyos";
		}
		
		# By extension
		if(length(arrExtCnt) > 0){
			for(eachExt in arrExtCnt){
				#print"extension: "ext;
				avgRspTimeByExt="";
				if(arrExtCnt[eachExt] > 0){
					avgRspTimeByExt=arrExtRspTmSum[eachExt]/arrExtCnt[eachExt];
					extRngPc=100/arrExtCnt[eachExt];
				}
				print eachExt, arrExtRange[eachExt","arrRangeName[1]]*extRngPc,arrExtRange[eachExt","arrRangeName[2]]*extRngPc,arrExtRange[eachExt","arrRangeName[3]]*extRngPc,arrExtRange[eachExt","arrRangeName[4]]*extRngPc,arrExtRange[eachExt","arrRangeName[5]]*extRngPc,arrExtCnt[eachExt],avgRspTimeByExt >> fTempHttp".perfbyext";
				#TBD - put some alert here.
			}
		}
		#--- new --- #
		# daily unique users by domain
		#arrDlyuUidDmn[uid","domain];
		# hourly unique users by domain
		#arrHrlUUidDmn[hour","uid","domain];
		# hourly jSesion by Domain
		#arrHrljSessDmn[hour","jsession","domain];
		#daily unique jSession by Domain
		#arrDlyjSessDmn[cloneID","jsession","domain];
		
		if(length(arrDmnLst) > 0){
			dmDlyHdFmt="%-35s\t%5s\t%5s\n";
			dmDlyBdFmt="%-35s\t%5d\t%5d\n";
			dmHrlyHdFmt="%-35s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\n";
			dmHrlyBdFmt="%-35s\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\t%5d\n";
			printf dmHrlyHdFmt,"Domain","H0","H1","H2","H3","H4","H5","H6","H7","H8","H9","H10","H11","H12","H13","H14","H15","H16","H17","H18","H19","H20","H21","H22","H23"> fTempHttp".hrlyUidSummByDmn";
			printf dmHrlyHdFmt,"Domain","H0","H1","H2","H3","H4","H5","H6","H7","H8","H9","H10","H11","H12","H13","H14","H15","H16","H17","H18","H19","H20","H21","H22","H23"> fTempHttp".hrlySessSummByDmn";
			printf dmDlyHdFmt,"Domain","uuc","usc"> fTempHttp".dlySummByDmn";
			for(eDmn in arrDmnLst){
				for(eRec in arrDlyuUidDmn){
					split(eRec,arrDlUidDmnLst,",");
					if(arrDlUidDmnLst[2] == eDmn){
						arrDlyDmnByUid[eDmn]++;
					}					
				}
				for(eRec in arrDlyjSessDmn){
					split(eRec,arrDlSessDmnLst,",");
					if(arrDlSessDmnLst[3] == eDmn){
						arrDlyDmnJsess[eDmn]++;
					}
				}
				# print daily
				printf dmDlyBdFmt,eDmn,arrDlyDmnByUid[eDmn],arrDlyDmnJsess[eDmn]>> fTempHttp".dlySummByDmn";
				# print hourly
				
				printf dmHrlyBdFmt,eDmn,arrHrlDmnByUuid["00,"eDmn],arrHrlDmnByUuid["01,"eDmn],arrHrlDmnByUuid["02,"eDmn],arrHrlDmnByUuid["03,"eDmn],arrHrlDmnByUuid["04,"eDmn],arrHrlDmnByUuid["05,"eDmn],arrHrlDmnByUuid["06,"eDmn],arrHrlDmnByUuid["07,"eDmn],arrHrlDmnByUuid["08,"eDmn],arrHrlDmnByUuid["09,"eDmn],arrHrlDmnByUuid["10,"eDmn],arrHrlDmnByUuid[11","eDmn],arrHrlDmnByUuid[12","eDmn],arrHrlDmnByUuid[13","eDmn],arrHrlDmnByUuid[14","eDmn],arrHrlDmnByUuid[15","eDmn],arrHrlDmnByUuid[16","eDmn],arrHrlDmnByUuid[17","eDmn],arrHrlDmnByUuid[18","eDmn],arrHrlDmnByUuid[19","eDmn],arrHrlDmnByUuid[20","eDmn],arrHrlDmnByUuid[21","eDmn],arrHrlDmnByUuid[22","eDmn],arrHrlDmnByUuid[23","eDmn] >> fTempHttp".hrlyUidSummByDmn";
				printf dmHrlyBdFmt,eDmn,arrHrlDmnBySess["00,"eDmn],arrHrlDmnBySess["01,"eDmn],arrHrlDmnBySess["02,"eDmn],arrHrlDmnBySess["03,"eDmn],arrHrlDmnBySess["04,"eDmn],arrHrlDmnBySess["05,"eDmn],arrHrlDmnBySess["06,"eDmn],arrHrlDmnBySess["07,"eDmn],arrHrlDmnBySess["08,"eDmn],arrHrlDmnBySess["09,"eDmn],arrHrlDmnBySess["10,"eDmn],arrHrlDmnBySess[11","eDmn],arrHrlDmnBySess[12","eDmn],arrHrlDmnBySess[13","eDmn],arrHrlDmnBySess[14","eDmn],arrHrlDmnBySess[15","eDmn],arrHrlDmnBySess[16","eDmn],arrHrlDmnBySess[17","eDmn],arrHrlDmnBySess[18","eDmn],arrHrlDmnBySess[19","eDmn],arrHrlDmnBySess[20","eDmn],arrHrlDmnBySess[21","eDmn],arrHrlDmnBySess[22","eDmn],arrHrlDmnBySess[23","eDmn] >> fTempHttp".hrlySessSummByDmn";

			}
		}
		
		#--- end of new --- #
		if(length(arrWhereUidStart) > 0){
			OFS=" ";
			print "ws","was","clnid","js","uid","strtm","endtm","diff" > fTempHttp".whereuid"
			for(ewhuidStrt in arrWhereUidStart){
				strTmstr=arrWhereUidStart[ewhuidStrt];
				split(strTmstr,strTmstrArr," ");
				strTm=strTmstrArr[1];
				strTmSec=strTmstrArr[2];
				endTmstr=arrWhereUidEnd[ewhuidStrt];
				if(endTmstr == ""){
					endTm="na";
					endTmSec="na";
					diff="na"
				} else {
					split(endTmstr,endTmstrArr," ");
					endTm=endTmstrArr[1];
					endTmSec=endTmstrArr[2];
					
					diff=endTmSec-strTmSec;
				}
				print ewhuidStrt,strTm,endTm,diff | whuidsrtcmd ;
			}
		}
		
		
	}'
	
	if [[ -e $fTempHttp.access_log_all ]]; then
		# read the temp file sort it by response time. Write top 10 in summary file and all other in access_log_all.csv report file
		sort -t'|' -k21nr $fTempHttp.access_log_all | \
		awk -vfTempHttp=$fTempHttp 'BEGIN \
		{
			FS=OFS="|";
			print "Host","Date","Time","tz","Hour","JSession","CloneID","WAS","Domain","Page","Extension","URL","Params","Protocol","Request","Response","Size","ByteRcvd","ByteSent","UID","RespTimeInSec","RangeInSec","Browser","OS","OS Flavor","OS Ver" > fTempHttp".access_log_all_sorted";
			
			acsHdFmt="%-15s\t%-12s\t%-8s\t%-30s\t%-15s\t%-6s\t%-3s\t%9s\t%5s\t%8s\t%-30s\t%-70s\t%-35s\n";
			acsBdFmt="%-15s\t%-12s\t%-8s\t%-30s\t%-15s\t%-6s\t%-3s\t%9.3f\t%5s\t%8d\t%-30s\t%-70s\t%-35s\n";
			print "" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "===== Top 10 (slowest) responses by Response Time =====" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			printf acsHdFmt,"ws","date","time","js","was","req","rsp","rt","rng","sz","uid","url","bwsr" >> fTempHttp".summary";
		
		} \
		{
			if(NR <=10){
				# Here is field values in the input file
				# $1:webSrvr;$2:dt;$3:tm;$4:tz;$5:hour;$6:jsession;$7:cloneID;$8:was;$9:domain;$10:page;$11:ext;$12:uriPath;$13:params;$14:protocol;$15:request
				# $16:response;$17:size;$18:byteRcvd;$19:byteSnt;$20:uid;$21:respTime;$22:respRange;$23:browser;$24:osName;$25:osFlav;$26:osVer.
				printf acsBdFmt,$1,$2,$3,$6,$8,$15,$16,$21,$22,$17,$20,$12,$23 >> fTempHttp".summary";				
			}
			print $0 >> fTempHttp".access_log_all_sorted";
			
		}'
	fi
	
	if [[ -e $fTempHttp.uri ]]; then
		sort -t'|' -k8nr $fTempHttp.uri | \
		awk -vfTempHttp=$fTempHttp -vrangeLst=$rangeLst 'BEGIN \
		{
			split(rangeLst,arrRangeName,"|");
			FS=OFS="|";
			uriHdFmt="%7s\t%7s\t%7s\t%7s\t%7s\t%9s\t%7s\t%9s\t%7s\t%-80s\n";
			uriBdFmt="%7.3f\t%7.3f\t%7.3f\t%7.3f\t%7.3f\t%9d\t%7.3f\t%9.3f\t%7.3f\t%-80s\n";
			uriHsfmt="%7s\t%7s\t%7s\t%7s\t%7s\t%9s\t%7s\t%7s\t%7s\t%9s\t%7s\t%-80s\n";
			uriBsfmt="%7.3f\t%7.3f\t%7.3f\t%7.3f\t%7.3f\t%9d\t%7.3f\t%7.3f\t%7.3f\t%9.3f\t%7.3f\t%-80s\n";
			print "" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "===== Top 10 (slowest) responses by Average Response Time =====" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			printf uriHdFmt,arrRangeName[1],arrRangeName[2],arrRangeName[3],arrRangeName[4],arrRangeName[5],"cnt","mnrt","mxrt","art","trn" >> fTempHttp".summary";
			printf uriHsfmt,arrRangeName[1],arrRangeName[2],arrRangeName[3],arrRangeName[4],arrRangeName[5],"cnt","mnrt","mxrt","art","bart","diff","trn" >> fTempHttp".uri.sorted";
		}		
		{
			if(NR <=10){
				printf uriBdFmt, $2,$3,$4,$5,$6,$7,$11,$12,$8,$1 >> fTempHttp".summary";
			}
			printf uriBsfmt,$2,$3,$4,$5,$6,$7,$11,$12,$8,$9,$10,$1 >> fTempHttp".uri.sorted";
		}'
	fi
	if [[ -e $fTempHttp.sumby400plsuri ]]; then
		sort -t'|' -k3nr $fTempHttp.sumby400plsuri | \
		awk -vfTempHttp=$fTempHttp -vrptSummaryBy400PlsUrl=$rptSummaryBy400PlsUrl 'BEGIN \
		{
			FS=OFS="|";
			print "" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "===== Top 10 (by count) URL ending with HTTP response code 400 and higher =====" >> fTempHttp".summary";
			print "===== for detail review file: "rptSummaryBy400PlsUrl" =====" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			
			rcuHdFmt="%3s\t%10s\t%-95s\n";
			rcuBdFmt="%3s\t%10d\t%-95s\n";
			printf rcuHdFmt,"rsp","cnt","url" >> fTempHttp".summary";
			printf rcuHdFmt,"rsp","cnt","url" > fTempHttp".sumby400plsuri.sorted";
		}
		{
			if(NR <= 10){
				printf rcuBdFmt,$2,$3,$1 >>  fTempHttp".summary";
			}
			printf rcuBdFmt,$2,$3,$1 >> fTempHttp".sumby400plsuri.sorted"
		}'
	fi
		
	if [[ -e $fTempHttp.bydmn ]]; then
		sort -t'|' -k2nr $fTempHttp.bydmn | \
		awk -vfTempHttp=$fTempHttp -vrptSummaryByDomain=$rptSummaryByDomain 'BEGIN \
		{
			FS=OFS="|";
			print "" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "===== Summary by Domain - Top 5 (slowest) by average response time =====" >> fTempHttp".summary";
			print "===== for detail review file: "rptSummaryByDomain" =====" >> fTempHttp".summary";
			print "Note: Domain response range and average response time excludes the following static contents from calculation:" >> fTempHttp".summary";
			print "excludes with these extensions: jpg|gif|png|ico|js|cgi|css|htm|html|pdf|null|doc|xlsx|xsl|aspx|txt|.css.xhtml|.js.xhtml|.png.xhtml|.gif.xhtml" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";			
			dmnHdFmt="%-20s\t%7s\t%8s\n";
			dmnBdFmt="%-20s\t%7.3f\t%8d\n";
			printf dmnHdFmt,"name","art","xrc" >> fTempHttp".summary";
			printf dmnHdFmt,"name","art","xrc" > fTempHttp".bydmn.sorted";
			
		}
		{
			if($3 > 0 && NR <= 5){
				#print top 5 (slowest) by average response time into summary file
				printf dmnBdFmt,$1,$2,$3 >> fTempHttp".summary"
			}
			printf dmnBdFmt,$1,$2,$3 >> fTempHttp".bydmn.sorted";
			 
		}'
	
	fi
	if [[ -e $fTempHttp.byuid ]]; then
		sort -t'|' -k8nr $fTempHttp.byuid | \
		awk -vfTempHttp=$fTempHttp -vrptPerfByUIDFile=$rptPerfByUIDFile -vrangeLst=$rangeLst 'BEGIN \
		{
			split(rangeLst,arrRangeName,"|");
			FS=OFS="|";
			uidHdFmt="%-40s\t%7s\t%7s\t%7s\t%7s\t%7s\t%9s\t%7s\n";
			uidBdFmt="%-40s\t%7.3f\t%7.3f\t%7.3f\t%7.3f\t%7.3f\t%9d\t%7.3f\n";			
			print "" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "===== Top 5 (slowest) UIDs by Average Response Time =====" >> fTempHttp".summary";
			print "===== for detail review file: "rptPerfByUIDFile" =====" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			printf uidHdFmt,"uid",arrRangeName[1],arrRangeName[2],arrRangeName[3],arrRangeName[4],arrRangeName[5],"xrc","art" >> fTempHttp".summary";
			printf uidHdFmt,"uid",arrRangeName[1],arrRangeName[2],arrRangeName[3],arrRangeName[4],arrRangeName[5],"xrc","art" > fTempHttp".byuid.sorted"
			
		}
		{
			if(NR <= 5){
				printf uidBdFmt,$1,$2,$3,$4,$5,$6,$7,$8 >> fTempHttp".summary";			
			}
			printf uidBdFmt,$1,$2,$3,$4,$5,$6,$7,$8 >> fTempHttp".byuid.sorted"
		}'
	fi
		
	if [[ -e $fTempHttp.perfbyext ]]; then
		sort -t'|' -k8nr $fTempHttp.perfbyext | \
		awk -vfTempHttp=$fTempHttp -vrangeLst=$rangeLst 'BEGIN \
		{
			split(rangeLst,arrRangeName,"|");
			FS=OFS="|";
			# summary by extension
			print "" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "===== Summary by Extension =====" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			extHdFmt="%-35s\t%7s\t%7s\t%7s\t%7s\t%7s\t%9s\t%7s\n";
			extBdFmt="%-35s\t%7.3f\t%7.3f\t%7.3f\t%7.3f\t%7.3f\t%9d\t%7.3f\n";
			printf extHdFmt,"Ext",arrRangeName[1],arrRangeName[2],arrRangeName[3],arrRangeName[4],arrRangeName[5],"cnt","art" >> fTempHttp".summary";
			
		}
		{
			printf extBdFmt,$1,$2,$3,$4,$5,$6,$7,$8 >> fTempHttp".summary";
		}'
	fi
	
	if [[ -e $fTempHttp.sumbybrwsr ]]; then
		sort -t'|' -k2nr $fTempHttp.sumbybrwsr | \
		awk -vfTempHttp=$fTempHttp 'BEGIN \
		{
			FS=OFS="|";
			bHdFmt="%-45s\t%9s\t%7s\n";
			bBdFmt="%-45s\t%9d\t%7.3f\n";
			print "" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "===== Browser Usage Statistics =====" >> fTempHttp".summary";
			print "cnt - total number of unique user using this browser" >> fTempHttp".summary";
			print "pc   - percentage usage of this browser" >> fTempHttp".summary";
			print "IE compatibility mode and Trident Token Description for Internet Explorer" >> fTempHttp".summary";
			print "Refer to: https://msdn.microsoft.com/en-us/library/ms537503(v=vs.85).aspx" >> fTempHttp".summary";
			print "Refer to: https://msdn.microsoft.com/en-us/library/hh869301(v=vs.85).aspx" >> fTempHttp".summary";
			print "Trident/7.0	--> IE11" >> fTempHttp".summary";
			print "Trident/6.0	--> Internet Explorer 10" >> fTempHttp".summary";
			print "Trident/5.0	--> Internet Explorer 9" >> fTempHttp".summary";
			print "Trident/4.0	--> Internet Explorer 8" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			printf bHdFmt,"Browser","cnt","pc" >> fTempHttp".summary";		
		}
		{
			printf bBdFmt,$1,$2,$3 >> fTempHttp".summary";
		}'
	fi
	if [[ -e $fTempHttp.sumbyos ]]; then
		sort -t'|' -k2nr $fTempHttp.sumbyos | \
		awk -vfTempHttp=$fTempHttp 'BEGIN \
		{
			FS=OFS="|";
			bHdFmt="%-45s\t%9s\t%7s\n";
			bBdFmt="%-45s\t%9d\t%7.3f\n";
			print "" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "===== OS Usage Statistics =====" >> fTempHttp".summary";
			print "cnt - total number of unique user using this OS" >> fTempHttp".summary";
			print "pc   - percentage usage of this OS" >> fTempHttp".summary";
			print "For list of microsoft version refer to:" >> fTempHttp".summary";
			print "https://en.wikipedia.org/wiki/List_of_Microsoft_Windows_versions" >> fTempHttp".summary";
			print "=====================================================" >> fTempHttp".summary";
			print "" >> fTempHttp".summary";
			printf bHdFmt,"OS","cnt","pc" >> fTempHttp".summary";
		}
		{
			printf bBdFmt,$1,$2,$3 >> fTempHttp".summary";
		}'
	fi
	
echo "========== End of Web Access Log Alert Section ==========" >> $rptAlertFile	
# copy to reporting dir  - network (shared) drive
# copy access log
if [[ -e $fTempHttp.access_log_all_sorted ]]; then
	mv $fTempHttp.access_log_all_sorted $rptAccessLogAllFile;
fi
if [[ -e $fTempHttp.discarded ]]; then
	mv $fTempHttp.discarded $rptDiscardedRecordsFile;
fi
if [[ -e $fTempHttp.summary ]]; then
	mv $fTempHttp.summary $rptSummaryFile;
fi
if [[ -e $fTempHttp.bydmn.sorted ]]; then
	mv $fTempHttp.bydmn.sorted $rptSummaryByDomain
fi
if [[ -e $fTempHttp.byuid.sorted ]]; then
	mv $fTempHttp.byuid.sorted $rptPerfByUIDFile;
fi
if [[ -e $fTempHttp.uri.sorted ]]; then
	mv $fTempHttp.uri.sorted $rptAvgRespTimeByURIFile;
fi
if [[ -e $fTempHttp.sumby400plsuri.sorted ]]; then
	mv $fTempHttp.sumby400plsuri.sorted $rptSummaryBy400PlsUrl;
fi

if [[ -e $fTempHttp.whereuid ]]; then
	mv $fTempHttp.whereuid $rptSummaryUserSession;
fi

if [[ -e $fTempHttp.unknownua ]]; then
	mv $fTempHttp.unknownua $rptUnknowUA;
fi

if [[ -e $fTempHttp.dlySummByDmn ]]; then
	mv $fTempHttp.dlySummByDmn $rptDomainUsgByDay;
fi

if [[ -e $fTempHttp.hrlyUidSummByDmn ]]; then
	mv $fTempHttp.hrlyUidSummByDmn $rptDomainUsgByUidByHr;	
fi
if [[ -e $fTempHttp.hrlySessSummByDmn ]]; then
	mv $fTempHttp.hrlySessSummByDmn $rptDomainUsgBySessByHr;
fi

#remove temp files	
trap 'rm -f $fTempHttp*' INT EXIT TERM;
echo "$0 completed at: "$(date +"%Y-%m-%dT%H:%M:%S")" with total execution time: "$SECONDS" sec" 2>&1 | tee -a $parserExeLog
echo "==================================================================" 2>&1 | tee -a $parserExeLog
