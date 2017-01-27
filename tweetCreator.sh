#!/bin/bash

# TODO Logging for each step
# TODO Timer
# TODO Get url from user
# TODO If url is empty use default url
# TODO Add exit statuses
# TODO ??TEST IT?? Add flag for category if no <category></category> in xml skip hashtagging
# TODO Remove or move to log 'echo msg' and add 't' command
# TODO Move parts to functions

## Set constants to calculate length of the message.
readonly TOTAL_LEN=140
readonly LINK_LEN=20
readonly BLANK_LEN=1
readonly HASHTAG_LEN=1

## Set constants for log.
readonly log="tweetCreator.log"
readonly LOG_NEW="BEGIN_LOG"
readonly LOG_PREFIX_FORMAT="%d/%m/%Y %H:%M"
readonly LOG_OK="OK:"
readonly LOG_WARNING="W:"
readonly LOG_ERROR="E:"

## Log function, log format:
## DATE-->LOG_STATUS LOG_MESSAGE|VAR_NAME0:VAR0|VAR_NAME1:VAR1|...<--
logging()
{
	local log_msg=$1
	local now=$(date "+$LOG_PREFIX_FORMAT")
	local log_prefix="$now-->"
	local log_posix="<--"
	test ! -f $log && (touch $log; echo -e "Log file is created at $now\n" > $log)
	if [ -z "$log_msg" ]; then
		return
	elif [ "$log_msg" == "$LOG_NEW" ]; then
		echo -e "\n------------------$now------------------\n" >> $log
	else
		echo -e "$log_prefix$log_msg$log_posix" >> $log
	fi
}

## Download xml file
path="rss_file_auto_created.xml"
url="http://feeds.mashable.com/Mashable?format=xml"

logging $LOG_NEW
echo "RSS feed file is downloading from $url"
wget -O $path $url -a $log
test ! -f $path && (echo "Something went wrong: File cannot be created, see $log!"; exit 1)
echo "File is created!"
logging "$LOG_OK Xml file is created.|Path:$path"

## Get Nth title and link from .xml file.
count=1
title=$(xmllint --xpath "string(//item[$count]/title)" $path)
link=$(xmllint --xpath "string(//item[$count]/link)" $path)

logging "$LOG_OK Starting main loop.|Title:$title|Url:$link"

withCategory=false
if [ -n "$(grep '<category>[A-Za-z0-9]*[</category>]*' $path)" ]; then
	withCategory=true
fi
## Do operations until title OR link are empty.
while [ -n "$title" ] || [ -n "$link" ]; do
	titleLen=${#title}
	currentLen=$(($titleLen + $BLANK_LEN + $LINK_LEN)) # Calculate message length without tags. 
	msg="$title $link" # Create a message without tags.
	
	if (("${#msg}" >= $TOTAL_LEN)); then
		count=$[$count + 1]
		title=$(xmllint --xpath "string(//item[$count]/title)" $path)
		link=$(xmllint --xpath "string(//item[$count]/link)" $path)
		logging "$LOG_WARNING Message is too long.|Msg:$msg|Len:${#msg}|Count:$count"
		continue
	fi
	
	if [ $withCategory ]; then
		## Get 3 tags that belong this title.
		logging "$LOG_OK Starting tag loop.|Msg:$msg"
		for i in 0 1 2; do
			tag[$i]=$(xmllint --xpath "string(//item[$count]/category[$i + 1])" $path | tr -d "[:blank:]") # 'tr' will remove white spaces.
			if [ -z "${tag[$i]}" ]; then
				continue
			fi
			tempLen=$(($currentLen + $BLANK_LEN + $HASHTAG_LEN + ${#tag[$i]}))
			## Add tags.
			if (("$tempLen" < "$TOTAL_LEN")); then
				msg="$msg #${tag[$i]}"
				currentLen=$tempLen
			fi
		done
	fi
	logging "$LOG_OK Message created.|Msg:$msg|Len:$currentLen|Count:$count"
	count=$[$count + 1]
	title=$(xmllint --xpath "string(//item[$count]/title)" $path)
	link=$(xmllint --xpath "string(//item[$count]/link)" $path)
done

exit 0
