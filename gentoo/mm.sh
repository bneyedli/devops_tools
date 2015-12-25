#!/bin/bash

set -u -o pipefail

PORTAGE_TMP=/var/tmp/portage/
PRETEND=0
SCRIPT_OUT=$(mktemp)
SCRIPT_FLAGS="-a ${SCRIPT_OUT} -q -c"
ARGS=""

die () {
  echo "$1"
  [[ -f ${SCRIPT_OUT} ]] && rm ${SCRIPT_OUT}
  checkMount '/var/tmp/portage/' && sudo /bin/umount /var/tmp/portage/
  exit "$2"
}

checkMount () {
  /bin/mount | /bin/grep ${1}
  return "$?"
}

#Need 1 arg
if (( ${#@} < 1 ))
then
  die "Specify a package to merge" '1'
elif [[ ${1} =~ ^- ]]
then
  echo "Params supplied: $1"
  (( ${#@} < 2 )) && die 'Please specify a package' '1'
  PACKAGE=$2
  ARGS=$1
  [[ ${ARGS} =~ "p" ]] && PRETEND=1
else
  PACKAGE=$1
fi

#Check if portage is mounted
checkMount '/var/tmp/portage/'
if (( $? > 0 )) 
then
  if (( PRETEND == 0 ))
  then
    echo "Mounting portage tmpfs"
    sudo /bin/mount /var/tmp/portage/ || die 'Unable to mount tmpfs' '1'
  fi
fi

if (( PRETEND == 1 ))
then
  sudo /usr/bin/emerge ${ARGS} ${PACKAGE}
  die 'fin' '0'
elif [[ -z ${ARGS} ]]
then
  ( script ${SCRIPT_FLAGS} "sudo /usr/bin/emerge ${PACKAGE}" &> /dev/null ) &
else
  ( script ${SCRIPT_FLAGS} "sudo /usr/bin/emerge ${ARGS} ${PACKAGE}" &> /dev/null ) &
fi

EMERGE_PID=$!

PRINT_STRING="Forked..."

while (( $? == 0 ))
do 
  echo "Merging..."
  echo "${PRINT_STRING}"
  EMERGE_STAT=$(genlop -c -q -i -t | egrep -v -e '!!!' -e 'see manpage' | sed 's/$/ /'|tr -d '\n')
  [[ -n ${EMERGE_STAT} ]] && PRINT_STRING=${EMERGE_STAT}
  sleep 1
  clear
  jobs 1 &> /dev/null
done

wait ${EMERGE_PID}
EMERGE_STATUS=$?

cat ${SCRIPT_OUT}

(( ! EMERGE_STATUS  == 0 )) && die "Emerge returned: ${EMERGE_STATUS}" "${EMERGE_STATUS}"
