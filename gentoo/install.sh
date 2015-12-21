#!/bin/bash

set -u -o pipefail

declare -r INSTALL_DIR='/usr/local/bin'
declare -r BASE='/usr/bin/basename'

set -u -o pipefail

die () {
  echo "${1}"
  exit "${2}"
}

[[ -f ./install.sh ]] || die "Please run from the same directory as project files"
(( UID == 0 )) || die "Please run as root"

for file in *.sh
do
  [[ ${file} == install.sh ]] && continue
  cp ${file} ${INSTALL_DIR}/$(${BASE} ${file} .sh)
  [[ ! -x ${INSTALL_DIR}/$(${BASE} ${file} .sh) ]] && ${CHMOD} 755 ${INSTALL_DIR}/$(${BASE} ${file} .sh)
done
