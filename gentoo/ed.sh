#!/bin/bash

set -u -o pipefail

declare -i gitPush='0'
declare -i gitPull='0'
declare -i gitCommit='0'

declare -i doSudo='0'

declare -r GIT='/usr/bin/git'
declare -r SUM='/usr/bin/md5sum'
declare -r AWK='/usr/bin/awk'
declare -r STAT='/usr/bin/stat'
declare -r GREP='/bin/egrep'
declare -r EDITOR='/usr/bin/vim'
declare -r SUDO='/usr/bin/sudo'
declare -r BASENAME='/usr/bin/basename'
declare -r DIRNAME='/usr/bin/dirname'

declare -r CUR_DIR=$( pwd )

#Do not go quietly into that good night
die () {
  echo "${1}"
  exit "${2}"
  cd ${CUR_DIR}
}

#wrapping git functions
runGit () {
  case $1 in
    push)
      echo "Pushing to git."
      gitOut=$( ${GIT} push 2>&1 ) || die "Could not push to git: ${gitOut}" '1'
    ;;
    pull)
      echo "Pulling from git."
      gitOut=$( ${GIT} pull 2>&1 ) || die "Could not pull from git: ${gitOut}" '1'
    ;;
    add)
      echo "Adding file: $2"
      gitOut=$( ${GIT} add ${2} 2>&1 ) || die "Could not git add ${2}: ${gitOut}" '1'
    ;;
    commit)
      gitOut=$( ${GIT} commit -m "${2}" 2>&1 ) || die "Could not commit: ${gitOut}" '1'
    ;;
    status)
      echo "Checking git status."
      #Check status of current repo -- thanks internet guy!
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
    ;; 
  esac
}

#Need one arg to continue
if (( ${#@} < 1 ))
then
  echo "Specify a file to hack on"
  exit 1
else
  declare TARGET=${1}
fi

WORK_DIR=$( ${DIRNAME} ${TARGET} )
TARGET=$( ${BASENAME} ${TARGET} )
cd ${WORK_DIR}

runGit status
retVal=$?

if (( retVal > 0 ))
then
  die "${retMsg}" "${retVal}"
fi

(( gitPush == 1 )) && runGit push && die "Changes pushed" "0"
(( gitPull == 1 )) && runGit pull && die "Changes pulled" "0"

[[ -f ${TARGET} ]] || die "No such file" '1'
[[ -w ${TARGET} ]] || doSudo='1'

(( gitPush == 1 )) && runGit 'push'
(( gitPull == 1 )) && runGit 'pull'

targetMtimePre=$(${STAT} ${TARGET} | ${GREP} ^Modify | ${SUM})
if (( doSudo == 1 ))
then
  ${SUDO} ${EDITOR} ${TARGET}
else
  ${EDITOR} ${TARGET}
fi
wait
targetMtimePost=$(${STAT} ${TARGET} | ${GREP} ^Modify| ${SUM})

[[ ! ${targetMtimePre} == ${targetMtimePost} ]] && gitCommit=1

#If we will be commiting, do thus
if (( gitCommit == 1 ))
then
  if [[ -f ./README.md ]]
  then
    MD5SUM=$(${SUM} ${TARGET} | ${AWK} '{ print $1 }')
    (( $? == 0 )) || die "Could not ${SUM} ${TARGET}" '1'

    #Check for existing md5sum
    egrep "^${TARGET}.*MD5" README.md &> /dev/null
    if (( $? == 0 ))
    then
      sed -i "s/\(^$(${BASENAME} ${TARGET}).*MD5:\).*$/\1 ${MD5SUM}/" README.md || die "Could not replace MD5" '1'
    else
      sed -i "s/\(^$(${BASENAME} ${TARGET}).*$\)/\1 \| MD5: ${MD5SUM}/" README.md || die "Could not append MD5: ${MD5SUM}" '1'
    fi
    runGit 'add' 'README.md'
  fi

  runGit 'add' "${TARGET}"

  echo -n "Commit message -> "
  read commitMessage

  [[ -z ${commitMessage} ]] && die "Commit aborted due to empty message" '1'

  #Commit the things
  runGit 'commit' "${commitMessage}"
fi

runGit status
if (( retVal > 0 ))
then
  die "${retMsg}" "${retVal}"
fi

(( gitPush == 1 )) && runGit push && die "Changes pushed" "0"
(( gitPull == 1 )) && runGit pull && die "Changes pulled" "0"

die "Nothing eh?" "0"
