#!/bin/bash

declare -i GZIP=0
declare -i FORCE=0
declare -i VERBOSITY=0

OUTFILE=user-data
PATH=cloud-init.d

die () {
	echo $2
	exit 1
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
	cd ${PATH}
	for file in *
	do
		STEP=${file/-*/}
		if [[ ${STEPS[@]} =~ ${STEP} ]]
		then
			(( VERBOSITY > 0 )) && echo "Multiple steps detected (ordering will be alphabetical): $STEP"	
		else
			STEPS+=" ${STEP}"
		fi
		
		headerCheck $file || continue
		INCLUDES+=" $file"
		
	done
}

while getopts "o:fvz" opt
do
	case ${opt} in
		f)
			FORCE=1
		;;
		o)
			OUTFILE=${OPTARG}
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

if (( GZIP == 1 ))
then
	if (( FORCE == 0 ))
	then
		checkFile ${OUTFILE}.mime.gz && die 1 "File exists, -f, if you mean it"
	fi
	/usr/bin/write-mime-multipart -z -o ${OUTFILE}.mime.gz ${INCLUDES}
else
	if (( FORCE == 0 ))
	then
		checkFile ${OUTFILE}.mime && die 1 "File exists, -f, if you mean it"
	fi
	/usr/bin/write-mime-multipart -o ${OUTFILE}.mime ${INCLUDES}
fi

#'#include': 'text/x-include-url',
#'#include-once': 'text/x-include-once-url',
#'#!': 'text/x-shellscript',
#'#cloud-config': 'text/cloud-config',
#'#cloud-config-archive': 'text/cloud-config-archive',
#'#upstart-job': 'text/upstart-job',
#'#part-handler': 'text/part-handler',
#'#cloud-boothook': 'text/cloud-boothook'
