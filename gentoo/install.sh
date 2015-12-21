#!/bin/bash

set -u -o pipefail

declare -r INSTALL_DIR='/usr/local/bin'
declare -r BASE='/usr/bin/basename'

set -u -o pipefail

die () {
  echo "${1}"
  exit "${2}"
}

[[ -f ./install.sh ]] || die "Please run from the same directory as project files" '1'
(( UID == 0 )) || die "Please run as root" '1'

for file in *.sh
do
  [[ ${file} == install.sh ]] && continue
  cp ${file} ${INSTALL_DIR}/$(${BASE} ${file} .sh) || die "Could not copy ${file} to ${INSTALL_DIR}" '1'
  if [[ ! -x ${INSTALL_DIR}/$(${BASE} ${file} .sh) ]]
  then
    ${CHMOD} 755 ${INSTALL_DIR}/$(${BASE} ${file} .sh) || die "Could not chmod ${file}"
  fi
done
die 'fin.' '0'
