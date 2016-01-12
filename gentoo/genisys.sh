#!/bin/bash

set -u -o pipefail

declare -r WGET='/usr/bin/wget'
declare -r CURL='/usr/bin/curl'
declare -r LFTP='/usr/bin/lftp'
declare -r GPG='/usr/bin/gpg'
declare -r SHA512SUM='/usr/bin/sha512sum'
declare -r OPENSSL='/usr/bin/openssl'

declare -ri CPU_COUNT=$(nproc)
declare -i SCRIPT_SCOPE='0'
declare -i VERBOSE='0'

declare -r COLOUR_RED='\033[0;31m'
declare -r COLOUR_GREEN='\033[0;32m'
declare -r COLOUR_RST='\033[0m'

declare BUILD_TARGET=""
declare -i BUILD_TARGET_STAGE=""

USERS=""
NO_MULTILIB='0'
SELINUX='0'
CATALYST_ARGS=''
CATALYST_BASE_DIR="$(grep ^storedir /etc/catalyst/catalyst.conf|cut -d\" -f2)"
CATALYST_TEMPLATE_DIR='/etc/catalyst/templates/common'
CATALYST_SNAPSHOT_CACHE="$(grep ^snapshot_cache /etc/catalyst/catalyst.conf|cut -d\" -f2)"
CATALYST_BUILD_CACHE="${CATALYST_BASE_DIR}/builds"


TIME_NOW=$(date +%s)
PORTAGE_SNAPSHOT_DATE=$(date +%s -r ${CATALYST_SNAPSHOT_CACHE}/portage-latest.tar.bz2)
PORTAGE_SNAPSHOT_AGE=$(( TIME_NOW - PORTAGE_SNAPSHOT_DATE ))
PORTAGE_SNAPSHOT_AGE_MAX='14400'

die () {
  (( $2 > 0 )) && log '2' "$1"
  (( $2 == 0 )) && log '1' "$1"
  exit $2
}

help () {
  log 1 "Usage:"
  echo -e "\t$(basename $0) -T { iso | ami | stage } -S { 1..4 } -A { amd64 | x86 } -N { myName } -P { hardened | soft }"
  echo -e "\t\tOptional args: -v [increment verbosity] -d [debug] -p [purge] -a [clear autoresume] -c [clear ccache]"
  echo
}

log () {
  case $1 in
    1)
      prefix=$(printf "%${SCRIPT_SCOPE}s")
      printf "${prefix// /\\t}${COLOUR_GREEN}->${COLOUR_RST} $2\n"
    ;;
    2)
      >&2  printf "${COLOUR_RED}***${COLOUR_RST} $2 ${COLOUR_RED}***${COLOUR_RST}\n"
    ;;
  esac
}

verifyTemplates () {
  local SCRIPT_SCOPE='1'
  case ${BUILD_TARGET_STAGE} in
    1)
      if [[ ${BUILD_TARGET} == 'livecd' ]]
      then
        TEMPLATES=( ${LIVECD_STAGE1_TEMPLATES[@]} )
      else
        TEMPLATES=( ${STAGE1_TEMPLATES[@]} )
      fi
    ;;
    2)
      if [[ ${BUILD_TARGET} == 'livecd' ]]
      then
        TEMPLATES=( ${LIVECD_STAGE2_TEMPLATES[@]} )
      else
        TEMPLATES=( ${STAGE2_TEMPLATES[@]} )
      fi
    ;;
    3)
      TEMPLATES=( ${STAGE3_TEMPLATES[@]} )
    ;;
    4)
      TEMPLATES=( ${STAGE4_TEMPLATES[@]} )
    ;;
  esac
  log '1' "Checking for templates"
  for template in ${TEMPLATES[@]}
  do 
      if [[ ! -f ${CATALYST_TEMPLATE_DIR}/${template} ]]
      then
          log '2' "Missing template: ${template}" 
          exit 1
      fi
  done
}

mangleTemplate () {
  template="${2}"
  var_names=( "${3}" )
  touch ${CATALYST_BUILD_CACHE}/${BUILD_NAME}/${SPEC_FILE} || return 1

  local SCRIPT_SCOPE='1'
  log '1' "Mangling template: ${template}"
  
  if [[ "$1" == "overwrite" ]] 
  then
    cp ${CATALYST_TEMPLATE_DIR}/${template} ${CATALYST_BUILD_CACHE}/${BUILD_NAME}/${SPEC_FILE}
    (( $? == 0 )) || return 1
  fi
  if [[ "$1" == "append" ]] 
  then
    cat ${CATALYST_TEMPLATE_DIR}/${template} >> ${CATALYST_BUILD_CACHE}/${BUILD_NAME}/${SPEC_FILE}
    (( $? == 0 )) || return 1
  fi

  for var in ${var_names[@]}
  do
    local SCRIPT_SCOPE='2'
    (( VERBOSE > 0 )) && log '1' "Processing: $var"
    var_name=${var}
    grep $var ${CATALYST_BUILD_CACHE}/${BUILD_NAME}/${SPEC_FILE} &> /dev/null || continue
    var_value=${!var}
    [[ "${var_value}" =~ '/' ]] && var_value=$(echo ${var_value}|sed 's/\//\\\//g')
    sed -i "s/###${var_name}###/${var_value}/g" ${CATALYST_BUILD_CACHE}/${BUILD_NAME}/${SPEC_FILE} &> /dev/null
    (( $? == 0 )) || return 1
  done

}

fetchRemote () {
  local method="$1"
  local url="$2"
  (( ${#@} == 3 )) && local dir="$3"
  case ${method} in
    simple)
      ${WGET} --directory-prefix=${dir} ${url} &>/dev/null
    ;;
    print)
      ${CURL} -s ${url}
    ;;
    parallel)
      ${LFTP} -c pget -O ${dir} ${url} &>/dev/null
    ;;
    *)
      log '2' "Method: ${method}, not understood"
      return 1
    ;;
  esac

  retVal=$?
  (( retVal > 0 )) && log '2' "Could not fetch ${url} to ${dir}" && return ${retVal}
  return 0
}

sumCheck () {
  local method="$1"
  local dir="$2"
  local file="$3"
  local digest="$4"
  local submethod="$5"

  local SCRIPT_SCOPE='1'

  case ${method} in
    sha512)
      cd ${dir}
      log '1' "Verifying ${method} hash for: ${file}"
      ${SHA512SUM} -c ${digest} | egrep -e ": OK$" | grep "${file}" &>/dev/null
      retVal=$?
      (( retVal == 0 )) || return "${retVal}"
    ;;
    openssl)
      log '1' "Verifying ${submethod} hash for: ${file} with: ${method}"
      hash=$(${OPENSSL} dgst -r -${submethod} ${dir}/${file}|awk '{print $1}')
      grep ${hash} ${dir}/${digest} &> /dev/null
      retVal=$?
      (( retVal == 0 )) || return "${retVal}"
    ;;
  esac
  return 0
}

sigCheck () {
  local SCRIPT_SCOPE='1'
  log '1' "Verifying GPG Signature for: $1"
  ${GPG} --verify $1 $2
  retVal=$?
  (( retVal == 0 )) || return "${retVal}"
}

runCatalyst () {
  local SCRIPT_SCOPE='1'
  local method="$1"
  case ${method} in
    snapshot)
      CATALYST_ARGS="${CATALYST_ARGS} -s"
      log '1' "Taking portage snapshot with args: ${CATALYST_ARGS}"
      /usr/bin/catalyst ${CATALYST_ARGS} latest
      retVal=$?
      (( retVal == 0 )) || return "${retVal}"
    ;;
    build)
      CATALYST_ARGS="${CATALYST_ARGS} -f"
      log '1' "Building with args: ${CATALYST_ARGS} ${CATALYST_BUILD_CACHE}/${BUILD_NAME}/${SPEC_FILE}"
      /usr/bin/catalyst ${CATALYST_ARGS} ${CATALYST_BUILD_CACHE}/${BUILD_NAME}/${SPEC_FILE}
      retVal=$?
      (( retVal == 0 )) || return "${retVal}"
    ;;
  esac
}

main () {
  log '1' "Starting run for: ${BUILD_NAME} with a ${REL_TYPE} stack on ${SUB_ARCH} for Stage: ${BUILD_TARGET_STAGE} for delivery by: ${BUILD_TARGET}"

  [[ -d ${CATALYST_BUILD_CACHE} ]] || mkdir -p ${CATALYST_BUILD_CACHE}

  if (( ${BUILD_TARGET_STAGE} == '1' ))
  then
    SRC_PATH_PREFIX="stage3-${SUB_ARCH}"
  else
    SRC_PATH_PREFIX="stage1-${SUB_ARCH}"
  fi

  if [[ ${BUILD_TARGET} == 'livecd' ]]
  then
    SRC_PATH_PREFIX="livecd-${SRC_PATH_PREFIX}"
  fi

  if [[ ${REL_TYPE} == 'hardened' ]]
  then
    SRC_PATH_PREFIX="${SRC_PATH_PREFIX}-${REL_TYPE}"
    (( NO_MULTILIB == 1 )) && SRC_PATH_PREFIX="${SRC_PATH_PREFIX}+nomultilib"
  else
    (( NO_MULTILIB == 1 )) && SRC_PATH_PREFIX="${SRC_PATH_PREFIX}-nomultilib"
  fi

  SRC_PATH="${BUILD_NAME}/${SRC_PATH_PREFIX}-${DIST_STAGE3_LATEST}"

  verifyTemplates "${SPEC_FILE}" || die "Could not verify templates" '1'
  mangleTemplate 'overwrite' "${SPEC_FILE}.header.template" "SUB_ARCH VERSION_STAMP REL_TYPE REL_PROFILE REL_SNAPSHOT SRC_PATH BUILD_NAME CPU_COUNT USERS BUILD_TARGET"
  (( $? == 0 )) || die "Could not manipulate spec file: header" '1'

  if (( ${BUILD_TARGET_STAGE} == '1' )) && [[ ${BUILD_TARGET} == 'livecd' ]]
  then
    cat ${CATALYST_TEMPLATE_DIR}/${SPEC_FILE}.pkg.template >> ${CATALYST_BUILD_CACHE}/${BUILD_NAME}/${SPEC_FILE}
    cat ${CATALYST_TEMPLATE_DIR}/${SPEC_FILE}.use.template >> ${CATALYST_BUILD_CACHE}/${BUILD_NAME}/${SPEC_FILE}
  fi

  if (( ${BUILD_TARGET_STAGE} == '2' )) && [[ ${BUILD_TARGET} == 'livecd' ]]
  then
    mangleTemplate 'append' "${SPEC_FILE}.boot.template" "REL_TYPE SUB_ARCH BUILD_TARGET TARGET_KERNEL"
    (( $? == 0 )) || die "Could not manipulate spec file: boot" '1'
    cat ${CATALYST_TEMPLATE_DIR}/${SPEC_FILE}.post.template >> ${CATALYST_BUILD_CACHE}/${BUILD_NAME}/${SPEC_FILE}
    (( $? == 0 )) || die "Could not manipulate spec file: post" '1'
  fi

  for file in "${DIST_STAGE3_DIGESTS}" "${DIST_STAGE3_CONTENTS}" "${DIST_STAGE3_ASC}" "${DIST_STAGE3_BZ2}"
  do
    if [[ ! -f ${CATALYST_SNAPSHOT_CACHE}/${file} ]] 
    then
      log '1' "Fetching $file"
      fetchRemote 'simple' "${DIST_BASE_URL}/${DIST_STAGE3_PATH}/${file}" "${CATALYST_SNAPSHOT_CACHE}"
      (( $? == 0 )) || die "Failed to fetch: ${file}" "$?"
    fi
  done

  log '1' "Verifying Stage Files"
  if [[ -f ${CATALYST_SNAPSHOT_CACHE}/${DIST_STAGE3_BZ2} ]]
  then
    sigCheck "${CATALYST_SNAPSHOT_CACHE}/${DIST_STAGE3_ASC}" "${CATALYST_SNAPSHOT_CACHE}/${DIST_STAGE3_DIGESTS}"
    (( $? == 0 )) || log '2' "Failed to verify signature"

    for file in "${DIST_STAGE3_BZ2}" "${DIST_STAGE3_CONTENTS}"
    do
      sumCheck 'openssl' "${CATALYST_SNAPSHOT_CACHE}" "${file}" "${DIST_STAGE3_DIGESTS}" sha512
      (( $? == 0 )) || die "SHA512 checksum failed for: ${file}" "$?"
      sumCheck 'openssl' "${CATALYST_SNAPSHOT_CACHE}" "${file}" "${DIST_STAGE3_DIGESTS}" whirlpool
      (( $? == 0 )) || die "Whirlpool checksum failed for: ${file}" "$?"
    done
  fi

  log '1' "Starting Catalyst run..."
  if (( BUILD_TARGET_STAGE == 1 ))
  then
    if (( PORTAGE_SNAPSHOT_AGE > PORTAGE_SNAPSHOT_AGE_MAX ))
    then 
      runCatalyst 'snapshot' || die "Catalyst failed to make a snapshot of portage" "$?"
    fi
  fi

  runCatalyst 'build' || die "Catalyst failed to build" "$?"
}

(( ${#@} < 1 )) && help && die "No arguments supplied" '1'
while getopts ":A:K:N:P:S:T:V:dnpsva" opt
do
  case ${opt} in
    A)
      SUB_ARCH="${OPTARG}"
    ;;
    K)
      TARGET_KERNEL="${OPTARG}"
    ;;
    N)
      BUILD_NAME="${OPTARG}"
    ;;
    P)
      REL_TYPE="${OPTARG}"
    ;;
    S)
      BUILD_TARGET_STAGE="${OPTARG}"
    ;;
    T)
      case ${OPTARG} in
        iso)
          BUILD_TARGET='livecd'
        ;;
        ami)
          BUILD_TARGET='ami'
        ;;
        stage)
          BUILD_TARGET='stage'
        ;;
        \?)
          die "Invalid Target specified: $OPTARG, should be one of [ iso, ami, stage ]" '1'
        ;;
      esac
    ;;
    V)
      FETCH_VERSION="${OPTARG}"
    ;;
    a)
      CATALYST_ARGS="${CATALYST_ARGS} -a"
    ;;
    d)
      CATALYST_ARGS="${CATALYST_ARGS} -d"
    ;;
    n)
      NO_MULTILIB='1'
    ;;
    v)
      CATALYST_ARGS="${CATALYST_ARGS} -v"
      (( VERBOSE++ ))
    ;;
    p)
      CATALYST_ARGS="${CATALYST_ARGS} -p -a"
      
    ;;
    s)
      SELINUX='1'
    ;;
    \?)
      die "Invalid option: -${OPTARG}" '1'
    ;;
  esac
done

if [[ ${BUILD_TARGET} == "livecd" ]]
then
  [[ ${BUILD_TARGET_STAGE} == [1-2] ]] || die "Need number of stage to build [1-2]" '1'
else
  [[ ${BUILD_TARGET_STAGE} == [1-4] ]] || die "Need number of stage to build [1-4]" '1'
fi 

REL_PROFILE="${REL_TYPE}/linux/${SUB_ARCH}"
(( NO_MULTILIB == 1 )) &&  REL_PROFILE="${REL_PROFILE}/no-multilib"
(( SELINUX == 1 )) &&  REL_PROFILE="${REL_PROFILE}/selinux"

(( VERBOSE >= 3 )) && set -x
(( VERBOSE == 2 )) && set -v

#todo: make this conditional
REL_SNAPSHOT='latest'

DIST_BASE_URL='http://distfiles.gentoo.org/releases'
DIST_STAGE3_PATH="${SUB_ARCH}/autobuilds/current-stage3-${SUB_ARCH}"
DIST_STAGE3_MANIFEST="latest-stage3-${SUB_ARCH}"

if [[ ${REL_TYPE} == 'hardened' ]] 
then
  DIST_STAGE3_PATH="${DIST_STAGE3_PATH}-${REL_TYPE}"
  DIST_STAGE3_MANIFEST="latest-stage3-${SUB_ARCH}-${REL_TYPE}"
  (( NO_MULTILIB == 1 )) && DIST_STAGE3_PATH="${DIST_STAGE3_PATH}+nomultilib"
  (( NO_MULTILIB == 1 )) && DIST_STAGE3_MANIFEST="${DIST_STAGE3_MANIFEST}+nomultilib"
else
  (( NO_MULTILIB == 1 )) && DIST_STAGE3_PATH="${DIST_STAGE3_PATH}-nomultilib"
  (( NO_MULTILIB == 1 )) && DIST_STAGE3_MANIFEST="${DIST_STAGE3_MANIFEST}-nomultilib"
fi

DIST_STAGE3_MANIFEST="${DIST_STAGE3_MANIFEST}.txt"

DIST_STAGE3_LATEST="$(fetchRemote 'print' ${DIST_BASE_URL}/${SUB_ARCH}/autobuilds/${DIST_STAGE3_MANIFEST}|grep bz2|cut -d/ -f1)"

DIST_STAGE3_PREFIX="stage3-${SUB_ARCH}"
if [[ ${REL_TYPE} == 'hardened' ]] 
then
  DIST_STAGE3_PREFIX="${DIST_STAGE3_PREFIX}-${REL_TYPE}"
  (( NO_MULTILIB == 1 )) && DIST_STAGE3_PREFIX="${DIST_STAGE3_PREFIX}+nomultilib"
else
  (( NO_MULTILIB == 1 )) && DIST_STAGE3_PREFIX="${DIST_STAGE3_PREFIX}-nomultilib"
fi

DIST_STAGE3_DIGESTS="${DIST_STAGE3_PREFIX}-${DIST_STAGE3_LATEST}.tar.bz2.DIGESTS"
DIST_STAGE3_CONTENTS="${DIST_STAGE3_PREFIX}-${DIST_STAGE3_LATEST}.tar.bz2.CONTENTS"
DIST_STAGE3_ASC="${DIST_STAGE3_PREFIX}-${DIST_STAGE3_LATEST}.tar.bz2.DIGESTS.asc"
DIST_STAGE3_BZ2="${DIST_STAGE3_PREFIX}-${DIST_STAGE3_LATEST}.tar.bz2"

VERSION_STAMP="${REL_TYPE}-${DIST_STAGE3_LATEST}"
(( NO_MULTILIB == 1 )) && VERSION_STAMP="${REL_TYPE}+nomultilib-${DIST_STAGE3_LATEST}"

SPEC_FILE="stage${BUILD_TARGET_STAGE}.spec"
[[ ${BUILD_TARGET} == livecd ]] && SPEC_FILE="livecd-${SPEC_FILE}"

LIVECD_STAGE1_TEMPLATES=( "${SPEC_FILE}.header.template" "${SPEC_FILE}.pkg.template" "${SPEC_FILE}.use.template" )
LIVECD_STAGE2_TEMPLATES=( "${SPEC_FILE}.header.template" "${SPEC_FILE}.boot.template" "${SPEC_FILE}.post.template" )
STAGE1_TEMPLATES=( "${SPEC_FILE}.header.template" )
STAGE2_TEMPLATES=( "${SPEC_FILE}.header.template" )
STAGE3_TEMPLATES=( "${SPEC_FILE}.header.template" )
STAGE4_TEMPLATES=( "${SPEC_FILE}.header.template" "${SPEC_FILE}.pkg.template" "${SPEC_FILE}.use.template" )

main

die "Fin." '0'
