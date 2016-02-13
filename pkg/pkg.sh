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
declare -A PKG_LIST=( [Deb]='dpkg -l' [RH]='rpm -qa' [Arch]='pacman -Q' [Gen]='cat /var/lib/portage/world' )
declare -A PKG_REMOVE=( [Deb]='apt-get remove' [RH]='yum remove' [Arch]='pacman -R' [Gen]='emerge --unmerge' )
declare -A PKG_UPDATE=( [Deb]='apt-get -y update' [RH]='yum update' [Arch]='pacman -S' [Gen]='emerge --sync' )
declare -A PKG_UPGRADE=( [Deb]='apt-get -y upgrade' [RH]='yum upgrade' [Arch]='pacman -Syu' [Gen]='emerge -NDu @world' )

declare DIST=''
declare PACKAGE=''

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

  declare -A PKG_ACTION=( [install]="${PKG_INSTALL[${DIST}]}" [list]="${PKG_LIST[${DIST}]}" [remove]="${PKG_REMOVE[${DIST}]}" [search]="${PKG_SEARCH[${DIST}]}" [update]="${PKG_UPDATE[${DIST}]}" [upgrade]="${PKG_UPGRADE[${DIST}]}" )
  (( VERBOSITY > 0 )) && START_TIME=$(date +%s)

  if [[ -z ${PACKAGE} ]]
  then
    ${PKG_ACTION[${ACTION}]} 
  else
    ${PKG_ACTION[${ACTION}]} ${PACKAGE}
  fi

  (( VERBOSITY == 0 )) && return
  timeElapsed START_TIME
  echo "Completed in: ${ELAPSED_TIME}"
}

while getopts "i:lr:s:uUv" opt
do
  case ${opt} in
    i)
      ACTION='install'
      PACKAGE=${OPTARG}
       
    ;;
    l)
      ACTION='list'
    ;;
    r)
      ACTION='remove'
      PACKAGE=${OPTARG}
    ;;
    s)
      ACTION='search'
      PACKAGE=${OPTARG}
    ;;
    u)
      ACTION='update'
    ;;
    U)
      ACTION='upgrade'
    ;;
    v)
      (( ++VERBOSITY ))
    ;;
  esac
done

main
exit
