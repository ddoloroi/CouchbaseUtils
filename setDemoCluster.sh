#!/bin/sh
#
# setupDemoCluster.sh
#

# default values
usessl=" "
nodes=1
rebalance="n"
user="Administrator"
password="password"
clusterip=192.168.1.161
port=8091
DataRAMQuota=830
IndexRAMQuota=410

verbose=1



ME=`basename $0 | sed 's/\.[^\.]*$//'`


_usage()
{
  echo "$ME [-s|--ssl] [-r|--rebalance] [-n #nodes] [-u user] [-p password] address"
  if [ $1 == 2 ]; then
    echo "-s: silent"
    echo "-s: silent"
  fi
  exit 1
}

# Test an IP address for validity:
# Usage:
#      valid_ip IP_ADDRESS
#      if [[ $? -eq 0 ]]; then echo good; else echo bad; fi
#
function isvalidIP()
{
  local  lip=$1
  local  rc=1

  if [[ $lip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    lip=($lip)
    IFS=$OIFS
    [[ ${lip[0]} -le 255 && ${lip[1]} -le 255 && ${lip[2]} -le 255 && ${lip[3]} -le 255 ]]
    rc=$?
  fi

  return $rc
}


# get command line switches
while getopts hHvsrn:u:p: param
do
  case "$param" in
     v)    verbose="y"         ;;
     n)    nodes=$OPTARG       ;;
     r)    rebalance="y"       ;;
     u)    user==$OPTARG       ;;
     p)    password==$OPTARG   ;;
     s)    usessl="- s"        ;;
     h)    _usage 2            ;;
     [?])  _usage 1            ;;
  esac
done
shift `expr $OPTIND - 1`

echo DEBUG debut processing
echo DEBUG verbose = $verbose
echo DEBUG usessl = $usessl
echo DEBUG nodes = $nodes
echo DEBUG user = $user
echo DEBUG password = $password
echo DEBUG DataRAMQuota = $DataRAMQuota
echo DEBUG IndexRAMQuota = $IndexRAMQuota
echo DEBUG rebalance=$rebalance
echo DEBUG clusterip=$clusterip

isvalidIP $clusterip
if [ ! $? -eq 0 ]; then
  echo Error: Wrong IP address format $clusterip
  exit 2
fi



if [ "$verbose" -eq 1 ]; then
  echo "Initialising cluster with node $clusterip..."
fi
couchbase-cli cluster-init -c $clusterip --cluster-username=$user --cluster-password=$password --cluster-init-port=$port \
              --cluster-ramsize=$DataRAMQuota --cluster-index-ramsize=$IndexRAMQuota --services=data,index,query

echo EXEC couchbase-cli server-list -c $clusterip -u=$user -p=$password
couchbase-cli server-list -c $clusterip -u=$user -p=$password

if [ $nodes -gt 1 -a $nodes -lt 9 ]; then

  # Adding nodes
  subnet=`echo $clusterip | cut -d . -f 1-3`
  firstip=`echo $clusterip | cut -d . -f 4`

  first=`expr $firstip + 1 `
  last=`expr $firstip + $nodes`

  count=$first
  # add logic to check whether we pass a 10's
  while [ $count -lt $last ]; do
    nodeip="$subnet.$count"
     
    if [ "$verbose" -eq 1 ]; then
      echo "Adding node $nodeip to cluster $clusterip:$port..."
    fi
    couchbase-cli server-add -c $clusterip -u $user -p $password --server-add=$nodeip:$port --services=data,index,query --server-add-username=$user --server-add-password=$user
    
    count=`expr $count + 1`
  done
fi

if [ "$verbose" -eq 1 ]; then
  couchbase-cli server-list -c $clusterip -u=$user -p=$password
fi

if [ "$rebalance" == "y" ]; then
  echo DEBUG rebalancing cluster
  echo EXEC couchbase-cli rebalance -c $clusterip:8091 -u $user -p $password
  couchbase-cli rebalance -c $clusterip:$port -u $user -p $password
  
  if [ "$verbose" -eq 1 ]; then
    couchbase-cli rebalance-status -c $clusterip:$port -u $user -p $password
  fi
fi

exit 0
