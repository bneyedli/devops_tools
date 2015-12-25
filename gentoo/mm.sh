#!/bin/bash

set -u -o pipefail

PORTAGE_TMP=/var/tmp/portage/
PRETEND=0
ARGS=""

#Need 1 arg
if (( ${#@} < 1 ))
then
  echo "Specify a package to merge"
  exit 1
elif [[ ${1} =~ ^- ]]
then
  echo "Params supplied: $1"
  (( ${#@} < 2 )) && echo "Please specify a package" && exit 1
  PACKAGE=$2
  ARGS=$1
  [[ ${ARGS} =~ "p" ]] && PRETEND=1
else
  PACKAGE=$1
fi

#Check if portage is mounted
( mount|grep /var/tmp/portage/ )
if (( $? > 0 )) 
then
  if (( PRETEND == 0 ))
  then
    echo "Mounting portage tmpfs"
    sudo /bin/mount /var/tmp/portage/ || exit 1
  fi
fi

if (( PRETEND == 1 ))
then
  sudo /usr/bin/emerge ${ARGS} ${PACKAGE}
  exit 0
elif [[ -z ${ARGS} ]]
then
  ( script -q -c "sudo /usr/bin/emerge ${PACKAGE}" &> /dev/null ) &
else
  ( script -q -c "sudo /usr/bin/emerge ${ARGS} ${PACKAGE}" &> /dev/null ) &
fi

EMERGE_PID=$!

PRINT_STRING="Forked..."

while (( $? == 0 ))
do 
  echo "${PRINT_STRING}"
  EMERGE_STAT=$(genlop -c -q -i -t | egrep -v -e '!!!' -e 'see manpage') #|sed 's/$/ /'|tr -d '\n')
  [[ -n ${EMERGE_STAT} ]] && PRINT_STRING=${EMERGE_STAT}
  sleep 1
  clear
  jobs 1 &> /dev/null
done

wait ${EMERGE_PID}
EMERGE_STATUS=$?

cat typescript

if (( ! EMERGE_STATUS  == 0 )) 
then
  echo "Emerge returned: ${EMERGE_STATUS}"
  exit 2
fi

sudo /bin/umount /var/tmp/portage/
