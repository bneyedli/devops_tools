#!/bin/bash
PORTAGE_TMP=/var/tmp/portage/

if (( ${#@} < 1 ))
then
  echo "Specify a package to merge"
  exit 1
fi

( mount|grep /var/tmp/portage/ )
if (( $? > 0 )) 
then
  echo "Mounting portage tmpfs"
  sudo /bin/mount /var/tmp/portage/ || exit 1
fi

sudo /usr/bin/emerge $1 &> emerge.out  &
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

cat emerge.out

if (( ! EMERGE_STATUS  == 0 )) 
then
  echo "Emerge returned: ${EMERGE_STATUS}"
  exit 2
fi

sudo /bin/umount /var/tmp/portage/
