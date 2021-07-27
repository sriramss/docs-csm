#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP

# Begin OSD conversion. Run on each node that has OSDs

function upgrade_osds () {
for host in $(ceph node ls| jq -r '.osd|keys[]')
 do
  for osd in $(ceph node ls| jq --arg host_key "$host" -r '.osd[$host_key]|values|tostring|ltrimstr("[")|rtrimstr("]")'| sed "s/,/ /g")
   do
     if [[ ! "$(ceph tell osd.$osd version|jq -r '.version')" =~ "15.2.8" ]]
     then
       timeout 300 ssh "$host" "cephadm --image $registry/ceph/ceph:v15.2.8 adopt --style legacy --name osd.$osd" --skip-pull
       if [ $? -ne 0 ]
          then
            ceph mgr fail $(ceph mgr dump | jq -r .active_name)
       fi
       sleep 10
       while [[ ! "$(ceph tell osd.$osd version|jq -r '.version')" =~ "15.2.8" ]]
       do
         sleep 10
       done
       until journalctl -u ceph-8ac73062-d556-46af-88f6-926d52036db3@osd.9 --no-pager |grep "nautilus -> octopus"
       do 
         sleep 10 
       done
     else
       echo "$osd has already been upgraded"
     fi
   done
   echo "Sleeping 3 mins between node OSD upgrades to allow background tasks to finish"
   sleep 180
   passed=0
   failed=0
   test=0
   for id in $(ceph osd ls-tree $host)
   do
    (( test++ ))
    if [[ "$(ceph tell osd.$id version|jq -r '.version')" =~ "15.2.8" ]]
    then
      (( passed++ ))
    else
      (( failed++ ))
    fi
   done
   echo "Tests: $test  Passed: $passed  Failed: $failed"


 done
 ceph osd require-osd-release octopus
}

# End  OSD conversion. Run on each node that has OSDs

