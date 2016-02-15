#!/bin/bash

set -u -o pipefail

declare -i VERBOSITY=0
declare -A IMAGE_SOURCE=( [amazon]='amazon' [marketplace]='aws-marketplace' [ubuntu]='099720109477' [centos]='679593333241' )
declare CACHE_DIR=/var/tmp/awscli-cache-${USER}
RELEASE_TYPE='stable'

timeElapsed () {
    END_TIME=$(date +%s)
    BUILD_TIME=$(( END_TIME - ${1} ))
    seconds=${BUILD_TIME}
    hours=$((seconds / 3600))
    seconds=$((seconds % 3600))
    minutes=$((seconds / 60))
    seconds=$((seconds % 60))
    ELAPSED_TIME="${hours}h:${minutes}m:${seconds}s"
}

awsDepCheck () {
  [[ -n ${AWS_REGION} ]] && echo "Region set to: ${AWS_REGION}" && return 0
  if [[ -f ${HOME}/.aws/config ]]
  then
    AWS_REGION=$(grep region ${HOME}/.aws/config|head -1|awk '{ print $3 }')
    return
  else
    echo "No region set"
    return 1
  fi
}

jsonCache () {
  local action=$1
  local facility=$2
  local work_dir="${CACHE_DIR}/${facility}/${AWS_REGION}"

  case $1 in
    verify)
      echo "Verifying Cache"
      [[ -n ${work_dir} ]] || return
      [[ -d ${work_dir} ]] || mkdir -p ${work_dir}
      [[ -f ${work_dir}/${ACCOUNT}.parsed ]] || return
      return
    ;;
    populate)
      echo "Populating Cache"
      aws ec2 --region us-east-1 describe-images --owners ${IMAGE_SOURCE[${ACCOUNT}]} --filters 'Name=image-type,Values=machine' --output json >> ${work_dir}/${ACCOUNT}.json || return
      jq '.Images[] | {Name, Description, Architecture, VirtualizationType, Hypervisor, RootDeviceType, ImageLocation, ImageId}' ${work_dir}/${ACCOUNT}.json | sed -e 's/}//' -e 's/{/%/' -e 's/"//g' -e 's/,//' > ${work_dir}/${ACCOUNT}.parsed || return
      return
    ;;
    purge)
      [[ -n ${work_dir} ]] || return
      echo "Checking for Stale Cache"
      find ${work_dir} -type f -mmin +360 -delete 
      return 0
    ;;
    query)
      local -i index=0
      while read line
      do
        if [[ $line =~ ^% ]] 
        then
          (( ++index ))
        elif [[ $line =~ ^"ImageLocation:" ]]
        then
          location=$line
          #if [[ $line =~ "${IMAGE_SOURCE[${ACCOUNT}]}/" || $line =~ "testing" ]]
          if [[ $line =~ "testing" ]]
          then
           testing=1
          else
           testing=0
          fi
        elif [[ $line =~ ^"Name:" ]]
        then
          name=$line
        elif [[ $line =~ ^"Description:" ]]
        then
          if [[ ! $line =~ "null" ]]
          then
            description=$line
          else
            description=""
          fi
        elif [[ $line =~ ^"Architecture:" ]]
        then
          arch=$line
        elif [[ $line =~ ^"VirtualizationType:" ]]
        then
          arch="$arch $line"
        elif [[ $line =~ ^"Hypervisor:" ]]
        then
          arch="$arch $line"
        elif [[ $line =~ ^"RootDeviceType:" ]]
        then
          arch="$arch $line"
        elif [[ $line =~ ^"ImageId:" ]]
        then
          (( testing == 1 )) && [[ ${RELEASE_TYPE} == "stable" ]] && continue
          (( testing == 0 )) && [[ ${RELEASE_TYPE} == "testing" ]] && continue
          ami=$line
          echo "Index: $index"
          echo "$name $description"
          echo $arch
          (( VERBOSITY > 0 )) && echo $location
          echo $ami
          echo
        fi
      done < ${work_dir}/${ACCOUNT}.parsed
    ;;
  esac
}

main () {
  awsDepCheck
  case ${ACTION} in
    owners)
      for owner in "${!IMAGE_SOURCE[@]}"
      do
        echo "$owner"
      done
    ;;
    search)
      START_TIME=$(date +%s)
      jsonCache purge images
      jsonCache verify images || jsonCache populate images
      jsonCache query images
      timeElapsed START_TIME
      echo "Completed in: ${ELAPSED_TIME}"
    ;;
  esac
}

while getopts "os:vR:T:" opt
do
  case ${opt} in
    o)
      ACTION='owners'
    ;;
    s)
      ACTION='search'
      ACCOUNT=${OPTARG}
    ;;
    v)
      (( ++VERBOSITY ))
    ;;
    R)
      AWS_REGION=${OPTARG}
    ;;
    T)
      RELEASE_TYPE=${OPTARG}
    ;;
  esac
done

main
exit
