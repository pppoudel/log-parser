# Log Parsing, Analysis, Correlation, and Reporting Engine written using AWK and Shell script.
<br/>
There are multiple tools/technologies available in the market that deal (searching, analyzing, monitoring etc.) with machine generated data/logs, but sometimes, you just need some light-weight
custom solution to deal with your specific situation and power of Shell scripting helps. I happened to be in such situation when I had to help a project team to identify performance issues, performance deviation, analyse and identify Java memory and Garbage Collection issues, troubleshoot production problem and identify root cause etc. and I ended up writing this solution. I'm sharing this with people, so that they can take it and customize and use as per their need.
<br/>
If interested, see my blog post Log Parsing, Analysis, correlation, and Reporting Engine for more details.

<br/>

Project has four parsers namely:
 * [websphereLogParser.sh for parsing, analyzing and reporting WebSphere Application Server (WAS) SystemOut.log](websphereLogParser.sh)
 * [webAccessLogParser.sh for parsing, analyzing and reporting Apache/IBM HTTP Server (IHS) access_log](webAccessLogParser.sh)
 * [webErrorLogParser.sh for parsing, analyzing and reporting Apache/IBM HTTP Server (IHS) error_log](webErrorLogParser.sh)
 * [javaGCStatsParser.sh for parsing, analyzing and reporting Java verbose Garbage Collection (GC) log.](javaGCStatsParser.sh)
<br/>
* Utility scripts:
 * masterLogParser.sh wrapper script for invoking above parsers all sequentially.
 * usage.sh - utility script - shows the help information.
<br/>
* Input files:
 * thresholdValues.csv
 * WAS_CloneIDs.csv
 * WASCustomFilter.txt
 * perfBaseLine.csv

I have written few blog posts about these parsers. See following for details:
1. [Log Parsing, Analysis, correlation, and Reporting Engine - General introduction.](https://purnapoudel.blogspot.com/2018/02/log-parsing-analysing-correlation-reporting-engine.html)
2. [How to Parse WebSphere Application Server Logs for Troubleshooting & Reporting - About WAS parser.](https://purnapoudel.blogspot.com/2018/02/how-to-parse-websphere-application-server-logs.html)
3. [How to Parse Apache access_Log for Troubleshooting & Reporting - about Apache access_log parser.](https://purnapoudel.blogspot.com/2018/02/how-to-parse-apache-access-logs.html)
4. [How to Parse Apache error_log for Troubleshooting & Reporting - about Apache error_log parser.](https://purnapoudel.blogspot.com/2018/02/how-to-parse-apache-error-logs.html)
5. [How to Parse WAS Verbose GC logs for Troubleshooting & Reporting - about Java GC log parser.](https://purnapoudel.blogspot.com/2018/02/how-to-parse-java-garbage-collection-logs.html)
