#!/bin/bash

declare -i GZIP=0
declare -i BASE64=0
declare -i FORCE=0
declare -i VERBOSITY=0

OUTFILE_PREFIX=user-data
OUTFILE_SUFFIX=mime

WRITE_ARGS=""
PARSE_DIR=/etc/cloud-init.d

die () {
	[[ -n $2 ]] && echo $2
	exit $1
}

printHelp () {
  echo "Script to parse files prefixed numerically (00-,01-...) in a directory (preset to /etc/cloud-init.d/) and combine as a mime-multipart file, optionally base64 encoding and/or gziping."
  echo
  echo "Example Use (base64 encode gzip and force overwrite with verbose output):"
  echo -e "\tcid -d /etc/cloud-init.d -o user-data -b -z -f -v"
  die 0 ""
}

checkFile () {
	(( VERBOSITY > 0 )) && echo "Checking file: $1"
	[[ -f $1 ]] && return 0
	(( VERBOSITY > 0 )) && echo "File: $1 not found"
	return 1
}

headerCheck () {
	HEADERS=( '#include' '#!' '#cloud-config' '#upstart-job' '#part-handler' '#cloud-boothook' )
	HEADER=$(/usr/bin/head -n1 $1)	
	for known in ${HEADERS[@]}
	do
		if [[ ${HEADER} =~ ${known} ]]
		then
			(( VERBOSITY > 0 )) && echo "Header: ${HEADER} is known" 
			return 0
		fi
	done
	return 1
}

processPath() {
	FILES_FOUND=$(find ${PARSE_DIR} -mindepth 1 -maxdepth 1 -type f -exec basename {} \;|sort -u)

	for file in ${FILES_FOUND}
	do
		STEP=${file/-*/}
		if [[ ${STEPS[@]} =~ ${STEP} ]]
		then
			(( VERBOSITY > 0 )) && echo "Multiple steps detected (ordering will be alphabetical): $STEP"	
		else
			STEPS+=" ${STEP}"
		fi
		
		headerCheck "${PARSE_DIR}/$file" || continue
		INCLUDES+=" ${PARSE_DIR}/$file"
	done
}

while getopts "d:o:bfhvz" opt
do
	case ${opt} in
		b)
			BASE64=1
		;;
		d)
			PARSE_DIR=${OPTARG}
		;;
		f)
			FORCE=1
		;;
		h)
			printHelp
		;;
		o)
			OUTFILE_PREFIX=${OPTARG}
		;;
		z)
			GZIP=1
			(( VERBOSITY > 1 )) && echo "Gzipping"
		;;
		v)
			(( ++VERBOSITY ))
		;;
	esac
done


processPath

OUTFILE="${OUTFILE_PREFIX}.${OUTFILE_SUFFIX}"

[[ -w $(dirname ${OUTFILE}) ]] || die 1 "Can't write! sudo?"

[[ -z ${INCLUDES} ]] && die 1 "Nothing to include, check your headers"

if (( FORCE == 0 ))
then
  checkFile ${OUTFILE} && die 1 "File exists, -f, if you mean it"
fi

/usr/local/bin/write-mime-multipart ${WRITE_ARGS} -o ${OUTFILE} ${INCLUDES}

if (( BASE64 == 1 ))
then
 /usr/bin/base64 ${OUTFILE} > ${OUTFILE}.b64
 OUTFILE="${OUTFILE}.b64"
fi

if (( GZIP == 1 ))
then
 /bin/gzip ${OUTFILE} 
fi

#'#include': 'text/x-include-url',
#'#include-once': 'text/x-include-once-url',
#'#!': 'text/x-shellscript',
#'#cloud-config': 'text/cloud-config',
#'#cloud-config-archive': 'text/cloud-config-archive',
#'#upstart-job': 'text/upstart-job',
#'#part-handler': 'text/part-handler',
#'#cloud-boothook': 'text/cloud-boothook'
