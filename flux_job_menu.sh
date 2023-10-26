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


    RAND_NUM=$((1 + $RANDOM % 10000))

    _OCA_INPUT=""
    read -p 'Enter your Flux Monitor Contract Address : ' _OCA_INPUT
    echo "-----------------------------------------------"
    
    ORACLE_ADDR="$(echo $_OCA_INPUT | sed '/^$/d;/^\\\s*$/d;s/^xdc/0x/g')"
    echo "Flux Monitor Oracle Contract Address is : $ORACLE_ADDR"
    echo
    echo

    #FUNC_FILE_CREATE;

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
        echo " $DSNUM is an integer.. progressing"
    else
        echo " $DSNUM is NOT an integer. Please enter integers only."
        FUNC_EXIT_ERROR;        
    fi



    if [ $DSNUM != "1" ]; then
        echo " checking var DSNUM... value of $DSNUM provided"
        #RAND_NUM=$((1 + $RANDOM % 10000))
        #JOB_TITLE="FLUX_POLL_IDLE_TIMER_${_FSYM_INPUT}_${_TSYMS_INPUT}_${RAND_NUM}"
        JOB_TITLE=""
        JOB_FNAME=""
        SINGLE_DS="false"
        FUNC_FILE_CREATE;
    else
        SINGLE_DS="true"
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

    echo "Your job filename: $JOB_FNAME has been successfully generated"
    FUNC_LOAD_JOB;
    FUNC_EXIT;
    
}


FUNC_LOAD_JOB(){

    # Checks that the node API is ready and accepting credentials
    plugin admin login -f $PLI_DEPLOY_PATH/apicredentials.txt > /dev/null 2>&1
    if [ $? != 0 ]; then
      echo
      echo  -e "${RED}## ERROR :: Plugin admin login encoutered issues${NC}"
      #sleep 2s
      exit
    else
      echo -e "${GREEN}INFO :: Successfully logged in with API credentials${NC}"
      #sleep 0.5s
    fi
    echo

    # Outputs return response from node API to raw tmp file based on toml blob
    plugin jobs create ~/$JOB_FNAME > /tmp/plivn_job_id.raw
    if [ $? != 0 ]; then
      echo
      echo  -e "${RED}## ERROR :: Plugin JOBS creation encoutered issues${NC}"
      cat /tmp/plivn_job_id.raw 
      sleep 2s
      exit
    else

      # Get Job ID for newly created job
      ext_job_id_raw="$(sudo -u postgres -i psql -d plugin_mainnet_db -t -c "SELECT external_job_id FROM jobs WHERE name = '$JOB_TITLE';")"
      if [[ ! -z "$ext_job_id_raw" ]]; then
        echo -e "${GREEN}INFO :: Successfully created JOB ID $JOB_TITLE ${NC}"
      else
        echo -e "${RED}ERROR :: JOB ID $JOB_TITLE failed to create${NC}"
        cat /tmp/plivn_job_id.raw
        FUNC_EXIT_ERROR
        #sleep 2s
      fi
    fi
    #echo

    # Get Job ID for newly created job
    #ext_job_id_raw="$(sudo -u postgres -i psql -d plugin_mainnet_db -t -c "SELECT external_job_id FROM jobs WHERE name = '$JOB_TITLE';")"
    
    # Remove hyphen separators
    ext_job_id=$(echo $ext_job_id_raw | tr -d \-)


    echo -e "${GREEN}---------------------------------------------------------------"
    echo
    echo -e "       Local node job id - Copy to your Solidity script"
    echo -e "================================================================="
    echo -e 
    echo -e "Oracle Contract Address is :   ${BYELLOW}$ORACLE_ADDR${GREEN}"
    echo -e "Job $JOB_TITLE ID is :   ${BYELLOW}$ext_job_id${GREEN}"
    echo 
    echo -e "URL for APIConsumer is :\n   ${BYELLOW}$FETCH_URL${NC}"
}



FUNC_GET_INPUTS(){

    # initialise variables with no values
    #JOB_TITLE=""
    #JOB_FNAME=""
    _FSYM_INPUT=""
    _TSYMS_INPUT=""
    FETCH_PATH=""


    read -p 'Enter FROM Pair (fsym) ticker : ' _FSYM_INPUT
    read -p 'Enter TO Pair (tsyms) ticker : ' _TSYMS_INPUT
    echo "------------------------------------------------------------------------------"
    echo


    echo "Data Source $DSINDEX FROM Pair (fsym) ticker is : $_FSYM_INPUT"
    echo "Data Source $DSINDEX TO Pair (tsyms) ticker is  : $_TSYMS_INPUT"

    if [ $SINGLE_DS == "true" ]; then
        #RAND_NUM=$((1 + $RANDOM % 10000))
        JOB_TITLE="FLUX_POLL_IDLE_TIMER_${_FSYM_INPUT}_${_TSYMS_INPUT}_${RAND_NUM}"
        JOB_FNAME="$JOB_TITLE.toml"
        echo "GET_INPUTS :: Your job filename is $JOB_FNAME "
        FUNC_FILE_CREATE;
    #else
    #elif [ $JOB_TITLE = "" ]; then
    #    JOB_TITLE="FLUX_MONITOR_POLL_IDLE_TIMER_${RAND_NUM}"
    #    JOB_FNAME="$JOB_TITLE.toml"
    #    echo "FILE_CREATE :: Your job filename is $JOB_FNAME "
    #    FUNC_FILE_CREATE;
    fi

    



    # initialise the array with key:value pairs
    declare -A _apiurl=( 
    ["Cryptocompare"]="https://min-api.cryptocompare.com/data/price?fsym=$_FSYM_INPUT&tsyms=$_TSYMS_INPUT"
    ["KuCoin"]="https://api.kucoin.com/api/v1/market/orderbook/level1?symbol=$_FSYM_INPUT-$_TSYMS_INPUT"
    ["BiTrue"]="https://openapi.bitrue.com/api/v1/ticker/price?symbol=$_FSYM_INPUT$_TSYMS_INPUT"
    ["Binance"]="https://api1.binance.com/api/v3/ticker/price?symbol=$_FSYM_INPUT$_TSYMS_INPUT"
    )

    echo
    echo "          Select the number for the API Provider you wish to use "
    echo
    echo "------------------------------------------------------------------------------"
    #for i in "${!_apiurl[@]}"; do
    #  echo "API Provider: $i"
    #done
    #echo "------------------------------------------------------------------------------"


    # Capture user input & call job creation function
    select _api in ${!_apiurl[@]} "QUIT" 
    do
        case "$_api" in
            Cryptocompare) echo; echo "   API Option: $_api" ; FETCH_URL=${_apiurl[$_api]}; FETCH_PATH="$_TSYMS_INPUT"; break ;;
            KuCoin) echo; echo "   API Option: $_api" ; FETCH_URL=${_apiurl[$_api]}; FETCH_PATH="data,price"; break ;;
            BiTrue) echo; echo "   API Option: $_api" ; FETCH_URL=${_apiurl[$_api]}; FETCH_PATH="price"; break ;;
            Binance*) echo; echo "   API Option: $_api" ; FETCH_URL=${_apiurl[$_api]}; FETCH_PATH="price"; break ;;
            "QUIT") echo "exiting now..." ; FUNC_EXIT; break ;;
            *) echo invalid option;;
        esac
    done

cat <<EOF >> ~/$JOB_FNAME
    // data source $DSINDEX
    ds${DSINDEX} [type="http" method=GET url="$FETCH_URL"]
    ds${DSINDEX}_parse [type="jsonparse" path="$FETCH_PATH"]
    ds${DSINDEX}_multiply     [type="multiply" input="\$(ds${DSINDEX}_parse)" times=10000]
    ds${DSINDEX} -> ds${DSINDEX}_parse -> ds${DSINDEX}_multiply -> medianized_answer
EOF


}


FUNC_FILE_CREATE(){

    #RAND_NUM=$((1 + $RANDOM % 10000))
    if [ $SINGLE_DS == "false" ]; then
        JOB_TITLE="FLUX_POLL_IDLE_TIMER_${RAND_NUM}"
        JOB_FNAME="$JOB_TITLE.toml"
        echo "FILE_CREATE :: Your job filename is $JOB_FNAME "
    fi

# Creates the job file and passed variable values 
cat <<EOF > ~/$JOB_FNAME
type = "fluxmonitor"
schemaVersion = 1
name = "$JOB_TITLE"
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