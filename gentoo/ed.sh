#!/bin/bash

set -u -o pipefail

declare -i gitPush='0'
declare -i gitPull='0'
declare -i gitCommit='0'

declare -i doSudo='0'

declare -r GIT='/usr/bin/git'
declare -r SUM='/usr/bin/md5sum'
declare -r SHA='/usr/bin/sha512sum'
declare -r STAT='/usr/bin/stat'
declare -r GREP='/bin/egrep'
declare -r EDITOR='/usr/bin/vim'
declare -r SUDO='/usr/bin/sudo'

if (( ${#@} < 1 ))
then
  echo "Specify a file to hack on"
  exit 1
fi

declare TARGET=${1}

die () {
  echo "${1}"
  exit "${2}"
}

#Check status of current repo
gitStatus () {
  gitPush=0
  gitPull=0
  LOCAL=$(${GIT} rev-parse @)
  REMOTE=$(${GIT} rev-parse @{u})
  BASE=$(${GIT} merge-base @ @{u})
  if [ $LOCAL = $REMOTE ]; then
    retMsg="Up-to-date"
    return 0
  elif [ $LOCAL = $BASE ]; then
    retMsg="Pull Required"
    gitPull=1
    return 0
  elif [ $REMOTE = $BASE ]; then
    retMsg="Push Required"
    gitPush=1
    return 0
  else
    retMsg="Divergent"
    return 1
  fi
}

gitStatus
retVal=$?

if (( retVal > 0 ))
then
  die "${retMsg}" "${retVal}"
fi

[[ -f ${TARGET} ]] || die "No such file" '1'
[[ -w ${TARGET} ]] || doSudo='1'

targetMtimePre=$(${STAT} ${TARGET} | ${GREP} ^Modify | ${SUM})
if (( doSudo == 1 ))
then
  ${SUDO} ${EDITOR} ${TARGET}
else
  ${EDITOR} ${TARGET}
fi
targetMtimePost=$(${STAT} ${TARGET} | ${GREP} ^Modify| ${SUM})

[[ ! ${targetMtimePre} == ${targetMtimePost} ]] && gitCommit=1

if (( gitCommit == 1 ))
then
  if [[ -f ./README.md ]]
  then
    SHASUM=$(${SHA} ${TARGET})
    egrep "^${TARGET}.*SHA:" README.md &> /dev/null
    if (( $? == 0 ))
    then
      sed -i "s/\(^${TARGET}.*SHA:\).*$/\1${SHASUM}/" README.md
    else
      sed -i "s/\(^${TARGET}.*$\)/\1 \| SHA: ${SHASUM}/" README.md
    fi
    ${GIT} add ./README.md
  fi

  ${GIT} add ${TARGET}
  ${GIT} commit
fi

gitStatus
if (( retVal > 0 ))
then
  die "${retMsg}" "${retVal}"
fi

(( gitPush == 1 )) && ${GIT} push && die "Changes pushed" "0"
(( gitPull == 1 )) && ${GIT} pull && die "Changes pulled" "0"
die "Nothing eh?" "0"
