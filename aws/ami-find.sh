#!/bin/bash

declare -i VERBOSITY=0
declare -A IMAGE_SOURCE=( [amazon]='amazon' [marketplace]='aws-marketplace' [ubuntu]='099720109477' [centos]='679593333241' )

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

main () {
  case ${ACTION} in
    owners)
      for owner in "${!IMAGE_SOURCE[@]}"
      do
        echo "$owner"
      done
    ;;
    search)
      aws ec2 describe-images --query Images[].[Name,Architecture,ImageLocation,Description] --owners ${IMAGE_SOURCE[${ACCOUNT}]} --output text
    ;;
  esac
}

while getopts "os:v" opt
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
  esac
done

main
exit
