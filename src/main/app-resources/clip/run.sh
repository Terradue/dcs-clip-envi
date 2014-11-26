#!/bin/bash
 
# source the ciop functions (e.g. ciop-log)
source ${ciop_job_include}

# define the exit codes
SUCCESS=0
ERR_NOINPUT=1
ERR_WRONGPROD=4
ERR_EOLI=5
ERR_NOEOLIRES=6

# add a trap to exit gracefully
function cleanExit ()
{
	local retval=$?
	local msg=""
	
	case "$retval" in
		$SUCCESS) msg="Processing successfully concluded";;
		$ERR_CURL) msg="Failed to retrieve the products";;
		$ERR_ADORE) msg="Failed during ADORE execution";;
		$ERR_PUBLISH) msg="Failed results publish";;
		$ERR_WRONGPROD) msg="Wrong product provided as input. Please use ASA_IMS_1P";;
		*) msg="Unknown error";;
	esac

	[ "$retval" != "0" ] && ciop-log "ERROR" "Error $retval - $msg, processing aborted" || ciop-log "INFO" "$msg"
	exit $retval
}
trap cleanExit EXIT


bbox="`ciop-getparam bbox`"

#TODO validate bbox value

while read dataset
do
  ciop-log "INFO" "Retrieve $dataset"

  retrieved="`opensearch-client "$inputfile" enclosure | ciop-copy -o $TMPDIR -`"

  # check if the file was retrieved
  [ "$?" == "0" -a -e "$retrieved" ] || exit $ERR_NOINPUT  

  # let's check if the correct product was provided
  series="`head -10 ${retrieved} | grep "^PRODUCT" | tr -d '"' | cut -d "=" -f 2 | cut -c 1-9`"

  [ "$series" == "ASA_IMS_1" ] || [ "$series" == "ASA_IM__0" ] || exit $ERR_WRONGPROD

  startdate="`date -d "$(head -11 ${retrieved} | grep "^SENSING_START" | tr -d '"' | cut -d "=" -f 2 | cut -c 1-20)" +%Y-%m-%dT%H:%M:%S`"
  stopdate="`date -d "$(head -11 ${retrieved} | grep "^SENSING_STOP" | tr -d '"' | cut -d "=" -f 2 | cut -c 1-20)" +%Y-%m-%dT%H:%M:%S`" 

  eoli=$TMPDIR/eoli
  cleoli -s $startdate -e $stopdate -b $bbox -c ESA.EECF.ENVISAT_ASA_IMx_xS > $eoli
  [ "$?" != "0" ] && exit $ERR_EOLI  

  results=`head -n 1 $eoli`

  [ "$results" == "0" ] && exit $ERR_NOEOLIRES 

  clipstart="`tail -n 1 $eoli | awk 'BEGIN { FS = "|" }; { print $6}'`"
  clipstop="`tail -n 1 $eoli | awk 'BEGIN { FS = "|" }; { print $7}'`"
  

done
