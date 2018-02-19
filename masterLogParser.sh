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
#	masterLogParser.sh 
# Master script that invokes other parsers.
# Execute as:
# ./masterLogParser.sh <options>

echo "==================================================================" 2>&1 | tee -a $parserExeLog
echo "$0 started at: "$(date +"%Y-%m-%dT%H:%M:%S") 2>&1 | tee -a $parserExeLog
echo "" 2>&1 | tee -a $parserExeLog
echo "" 2>&1 | tee -a $parserExeLog
echo "Invoking websphereLogParser" 2>&1 | tee -a $parserExeLog
sh ./websphereLogParser.sh "$@"
echo "" 2>&1 | tee -a $parserExeLog
echo "" 2>&1 | tee -a $parserExeLog
echo "Invoking webAccessLogParser" 2>&1 | tee -a $parserExeLog
sh ./webAccessLogParser.sh "$@"
echo "" 2>&1 | tee -a $parserExeLog
echo "" 2>&1 | tee -a $parserExeLog
echo "Invoking webErrorLogParser" 2>&1 | tee -a $parserExeLog
sh ./webErrorLogParser.sh "$@"
echo "" 2>&1 | tee -a $parserExeLog
echo "" 2>&1 | tee -a $parserExeLog
echo "Invoking javaGCStatsParser" 2>&1 | tee -a $parserExeLog
sh ./javaGCStatsParser.sh "$@"
echo "" 2>&1 | tee -a $parserExeLog
echo "" 2>&1 | tee -a $parserExeLog
echo "$0 completed at: "$(date +"%Y-%m-%dT%H:%M:%S")" with total execution time: "$SECONDS" sec" 2>&1 | tee -a $parserExeLog
echo "==================================================================" 2>&1 | tee -a $parserExeLog
