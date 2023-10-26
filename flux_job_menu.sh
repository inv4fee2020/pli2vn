#!/bin/bash
#set -x

PLI_VARS_FILE="plinode_$(hostname -f).vars"
source ~/$PLI_VARS_FILE

GREEN='\033[0;32m'
#RED='\033[0;31m'
RED='\033[0;91m'  # Intense Red
YELLOW='\033[0;33m'
BYELLOW='\033[1;33m'
NC='\033[0m' # No Color


# Authenticate sudo perms before script execution to avoid timeouts or errors
sudo -l > /dev/null 2>&1


FUNC_START(){


    _OCA_INPUT=""
    read -p 'Enter your Flux Monitor Contract Address : ' _OCA_INPUT
    echo "-----------------------------------------------"
    
    ORACLE_ADDR="$(echo $_OCA_INPUT | sed '/^$/d;/^\\\s*$/d;s/^xdc/0x/g')"
    echo "Flux Monitor Oracle Contract Address is : $ORACLE_ADDR"
    echo
    echo
    FUNC_FILE_CREATE;

    # Get user input
    read -r -p "Enter the number of Data Sources to use: " DSNUM
    
    # Make sure input is provided else die with an error
    if [[ "$DSNUM" == "" ]]
    then
        echo "$0 - Input is missing." 
        FUNC_EXIT_ERROR;
    fi
    
    # The regular expression matches digits only 
    if [[ "$DSNUM" =~ ^[0-9]+$ || "$DSNUM" =~ ^[-][0-9]+$  ]]
    then
        echo "$0 - $DSNUM is an integer.. progressing"
    else
        echo "$0 - $DSNUM is NOT an integer. Please enter integers only."
        FUNC_EXIT_ERROR;        
    fi

    echo "------------------------------------------------------------------------------"
    for (( DSINDEX=1; DSINDEX<=$DSNUM; DSINDEX++ )) do
      echo "Data Source : $DSINDEX"
      FUNC_GET_INPUTS;
    done
    echo "------------------------------------------------------------------------------"
cat <<EOF >> ~/$JOB_FNAME
medianized_answer [type=median]
"""
EOF



    ##!/bin/bash
    ## set counter 'c' to 1 and condition 
    ## c is less than or equal to 5
    #for (( c=1; c<=5; c++ ))
    #do 
    #   echo "Welcome $c times"
    #done
}



FUNC_GET_INPUTS(){


    #echo -e "${GREEN}#"
    #echo -e "#   This script generates the necessary toml blob for a Flux Monitor Job-Setup section in the docs"
    #echo -e "#   source: https://docs.goplugin.co/plugin-2.0/job-setup/flux-monitor-job/poll-timer-+-idle-timer-recommended"
    #echo -e "#"
    #echo -e "#   The script removes the "-" hyphen from the original returned 'external_job_id' value"
    #echo -e "#"
    #echo -e "#   The script checks for leading  / trailing white spaces and removes as necessary"
    #echo -e "#   & converts the 'xdc' prefix to '0x' as necessary"
    #echo -e "#"
    #echo -e "#${NC}"
    #sleep 0.5s
    ##source ~/"plinode_$(hostname -f)".vars


    # initialise variables with no values
    _FSYM_INPUT=""
    _TSYMS_INPUT=""

    read -p 'Enter FROM Pair (fsym) ticker : ' _FSYM_INPUT
    read -p 'Enter TO Pair (tsyms) ticker : ' _TSYMS_INPUT
    #echo "-----------------------------------------------"
    #echo
    #FUNC_API_MENU;

    echo "Data Source $DSINDEX FROM Pair (fsym) ticker is : $_FSYM_INPUT"
    echo "Data Source $DSINDEX TO Pair (tsyms) ticker is  : $_TSYMS_INPUT"

cat <<EOF >> ~/$JOB_FNAME
    // data source "$DSINDEX"
    ds${DSINDEX} [type="http" method=GET url="https://min-api.cryptocompare.com/data/price?fsym=PLI&tsyms=USDT"]
    ds${DSINDEX}_parse" [type="jsonparse" path="USDT"]
    ds${DSINDEX}_multiply"     [type="multiply" input="$(ds${DSINDEX}_parse)" times=10000]
    ds${DSINDEX} -> ds${DSINDEX}_parse" -> ds${DSINDEX}_multiply" -> medianized_answer
EOF


}


FUNC_FILE_CREATE(){
    RAND_NUM=$((1 + $RANDOM % 10000))
    JOB_TITLE="FLUX_MONITOR_POLL_IDLE_TIMER_${RAND_NUM}"
    JOB_FNAME="$JOB_TITLE.toml"

# Creates the job file and passed variable values 
cat <<EOF > ~/$JOB_FNAME
type = "fluxmonitor"
schemaVersion = 1
name = "Flux Poll Timer + Idle Timer"
forwardingAllowed = false
maxTaskDuration = "30s"
absoluteThreshold = 0
contractAddress = "$ORACLE_ADDR"
drumbeatEnabled = false
drumbeatSchedule = "CRON_TZ=UTC * */20 * * * *"
idleTimerPeriod = "30s"
idleTimerDisabled = true
pollTimerPeriod = "1m0s"
pollTimerDisabled = true
threshold = 0.5
observationSource = """
EOF
}



FUNC_EXIT(){
	exit 0
	}


FUNC_EXIT_ERROR(){
  echo "An error has occurred.  exiting.."
	exit 1
}
  


FUNC_START