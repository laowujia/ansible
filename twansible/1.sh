#!/bin/bash
function CheckIPAddr () {
echo $1 |grep "^[0-9]\{1,3\}\.\([0-9]\{1,3\}\.\)\{2\}[0-9]\{1,3\}$" >/dev/null;
if [ $? -ne 0 ]
then
	return 1
fi
ipaddr=$1
a=`echo $ipaddr|awk -F . '{print $1}'`
b=`echo $ipaddr|awk -F . '{print $2}'`
c=`echo $ipaddr|awk -F . '{print $3}'`
d=`echo $ipaddr|awk -F . '{print $4}'`
for num in $a $b $c $d 
do 
  if [ $num -gt 255 ] || [ $num -lt 0 ]
  then
     return 1
    fi
done
   return 0 
}
CheckIPAddr $1
