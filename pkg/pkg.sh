#!/bin/bash

declare -i VERBOSITY=0
declare -i RPM_HANDLER=0
declare -i YUM_HANDLER=0
declare -i APT_HANDLER=0
declare -i EMERGE_HANDLER=0
declare -i PACMAN_HANDLER=0

declare -A PKG_HANDLER=( [Deb]='apt-get' [RH]='yum' [Arch]='pacman' [Gen]='emerge' )
declare -A PKG_SEARCH=( [Deb]='apt-cache search' [RH]='yum search' [Arch]='pacman -Ss' [Gen]='emerge --search' )
declare -A PKG_INSTALL=( [Deb]='apt-get -y install' [RH]='yum -y install' [Arch]='pacman -Ss' [Gen]='emerge --search' )
declare -A PKG_REMOVE=( [Deb]='apt-get remove' [RH]='yum remove' [Arch]='pacman -R' [Gen]='emerge --unmerge' )
declare -A PKG_UPDATE=( [Deb]='apt-get -y update' [RH]='yum update' [Arch]='pacman -S' [Gen]='emerge --sync' )
declare -A PKG_UPGRADE=( [Deb]='apt-get -y upgrade' [RH]='yum update' [Arch]='pacman -Syu' [Gen]='emerge -NDu @world' )

declare DIST=''

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


distroDetect () {
	case $1 in
    1)
      #rh based
      [[ -f /etc/redhat-release ]] && DIST='RH' && return 0
      which rpm &> /dev/null && RPM_HANDLER='1'
      which yum  &> /dev/null && YUM_HANDLER='1'
      (( RPM_HANDLER == 1 || YUM_HANDLER == 1 )) && DIST='RH' && return 0
      return 1
    ;;
    2)
      #deb based
      which apt-get &> /dev/null  && APT_HANDLER='1'
      (( APT_HANDLER == 1 )) && DIST="Deb" && return 0
      return 1
    ;;
    3)
      #gentoo based
      which emerge &> /dev/null && EMERGE_HANDLER='1'
      which eix &> /dev/null && EIX_HANDLER='1'
      (( EMERGE_HANDLER == 1 || EIX_HANDLER == 1 )) && DIST="Gen" && return 0
      return 1
    ;;
    4)
      #arch based
      which pacman &> /dev/null && PACMAN_HANDLER='1' && DIST="Arch" && return 0
      return 1
    ;;
  esac
}

main () {
  for i in $( seq 1 4 )
  do
    distroDetect $i && break
  done
}

while getopts "i:r:s:uUv" opt
do
  case ${opt} in
    i)
      INSTALL=1
      PACKAGE=${OPTARG}
      main
      ${PKG_INSTALL[${DIST}]} ${PACKAGE}
      (( VERBOSITY == 0 )) && exit 
      timeElapsed START_TIME
      echo "Completed in: ${ELAPSED_TIME}"
       
    ;;
    r)
      REMOVE=1
      PACKAGE=${OPTARG}
      main
      ${PKG_REMOVE[${DIST}]} ${PACKAGE}
      (( VERBOSITY == 0 )) && exit 
      timeElapsed START_TIME
      echo "Completed in: ${ELAPSED_TIME}"
    ;;
    s)
      SEARCH=1
      PACKAGE=${OPTARG}
      START_TIME=$(date +%s)
      main
      ${PKG_SEARCH[${DIST}]} ${PACKAGE}
      (( VERBOSITY == 0 )) && exit 
      timeElapsed START_TIME
      echo "Completed in: ${ELAPSED_TIME}"
    ;;
    u)
      UPDATE=1
      START_TIME=$(date +%s)
      main
      ${PKG_UPDATE[${DIST}]}
      (( VERBOSITY == 0 )) && exit 
      timeElapsed START_TIME
      echo "Completed in: ${ELAPSED_TIME}"
    ;;
    u)
      UPGRADE=1
      START_TIME=$(date +%s)
      main
      ${PKG_UPDGRADE[${DIST}]}
      (( VERBOSITY == 0 )) && exit 
      timeElapsed START_TIME
      echo "Completed in: ${ELAPSED_TIME}"
    ;;
    v)
      (( ++VERBOSITY ))
    ;;
  esac
done

main
