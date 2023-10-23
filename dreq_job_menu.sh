#!/bin/bash
#set -x

PLI_VARS_FILE="plinode_$(hostname -f).vars"
source ~/$PLI_VARS_FILE

GREEN='\033[0;32m'
NC='\033[0m' # No Color
RAND_NUM=$((1 + $RANDOM % 10000))
JOB_TITLE="cryptocompare_XDC_USD_test_$RAND_NUM"
JOB_FNAME="pli2vn_testjob_CC_USD_XDC.toml"

#clear


FUNC_GET_INPUTS(){

    echo -e "${GREEN}#"
    echo -e "#   This script generates the necessary toml blob for a Direct Request Job-Setup section in the docs"
    echo -e "#   source: https://docs.goplugin.co/plugin-2.0/job-setup/steps-to-setup-direct-request-job"
    echo -e "#"
    echo -e "#   The script removes the "-" hyphen from the original returned 'external_job_id' value"
    echo -e "#"
    echo -e "#   The script checks for leading  / trailing white spaces and removes as necessary"
    echo -e "#   & converts the 'xdc' prefix to '0x' as necessary"
    echo -e "#"
    echo -e "#${NC}"
    sleep 0.5s
    #source ~/"plinode_$(hostname -f)".vars


    # initialise variables with no values
    _FSYM_INPUT=""
    _TSYMS_INPUT=""

    read -p 'Enter FROM Pair (fsym) ticker : ' _FSYM_INPUT
    read -p 'Enter TO Pair (tsyms) ticker : ' _TSYMS_INPUT
    echo "-----------------------------------------------"
    echo
    read -p 'Enter your Oracle Contract Address : ' _INPUT
    echo "-----------------------------------------------"
    #ORACLE_ADDR="xdc268035b8D5d0a583007f6b8443E31C9c650FcbE1"
    ORACLE_ADDR="$(echo $_INPUT | sed '/^$/d;/^\\\s*$/d;s/^xdc/0x/g')"
    FUNC_API_MENU;
}


FUNC_CREATE_JOB(){

# Creates the job file and passed variable values 
cat <<EOF > ~/$JOB_FNAME
type = "directrequest"
schemaVersion = 1
name = "$JOB_TITLE"
maxTaskDuration = "0s"
contractAddress = "$ORACLE_ADDR"
minIncomingConfirmations = 0
observationSource = """
    decode_log   [type="ethabidecodelog"
                  abi="OracleRequest(bytes32 indexed specId, address requester, bytes32 requestId, uint256 payment, address callbackAddr, bytes4 callbackFunctionId, uint256 cancelExpiration, uint256 dataVersion, bytes data)"
                  data="\$(jobRun.logData)"
                  topics="\$(jobRun.logTopics)"]

    decode_cbor  [type="cborparse" data="\$(decode_log.data)"]
    fetch        [type="http" method=GET url="$FETCH_URL" allowUnrestrictedNetworkAccess="true"]
    parse        [type="jsonparse" path="USD" data="\$(fetch)"]

    multiply     [type="multiply" input="\$(parse)" times="\$(decode_cbor.times)"]

    encode_data  [type="ethabiencode" abi="(bytes32 requestId, uint256 value)" data="{ \\\"requestId\\\": \$(decode_log.requestId), \\\"value\\\": \$(multiply) }"]
    encode_tx    [type="ethabiencode"
                  abi="fulfillOracleRequest2(bytes32 requestId, uint256 payment, address callbackAddress, bytes4 callbackFunctionId, uint256 expiration, bytes calldata data)"
                  data="{\\\"requestId\\\": \$(decode_log.requestId), \\\"payment\\\":   \$(decode_log.payment), \\\"callbackAddress\\\": \$(decode_log.callbackAddr), \\\"callbackFunctionId\\\": \$(decode_log.callbackFunctionId), \\\"expiration\\\": \$(decode_log.cancelExpiration), \\\"data\\\": \$(encode_data)}"
                  ]
    submit_tx    [type="ethtx" to="$ORACLE_ADDR" data="\$(encode_tx)"]

    decode_log -> decode_cbor -> fetch -> parse -> multiply -> encode_data -> encode_tx -> submit_tx
"""
EOF

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
      echo -e "${GREEN}INFO :: Successfully created JOB ID $JOB_TITLE ${NC}"
      cat /tmp/plivn_job_id.raw 
      sleep 2s
    fi
    #echo

    # Get Job ID for newly created job
    ext_job_id_raw="$(sudo -u postgres -i psql -d plugin_mainnet_db -t -c "SELECT external_job_id FROM jobs WHERE name = '$JOB_TITLE';")"
    
    # Remove hyphen separators
    ext_job_id=$(echo $ext_job_id_raw | tr -d \-)


    echo -e "${GREEN}---------------------------------------------------------------"
    echo
    echo -e "       Local node job id - Copy to your Solidity script"
    echo -e "================================================================="
    echo -e 
    echo -e "Oracle Contract Address is :   $ORACLE_ADDR"
    echo -e "Job $JOB_TITLE ID is :   $ext_job_id "
    echo 
    echo -e "URL for APIConsumer is :\n   $FETCH_URL${NC}"
  }



FUNC_EXIT(){
	exit 0
	}


FUNC_EXIT_ERROR(){
	exit 1
}
  



FUNC_API_MENU(){

    # initialise the array with key:value pairs
    declare -A _apiurl=( 
    ["Cryptocompare"]="https://min-api.cryptocompare.com/data/price?fsym=$_FSYM_INPUT&tsyms=$_TSYMS_INPUT"
    ["KuCoin"]="https://api.kucoin.com/api/v1/market/orderbook/level1?symbol=$_FSYM_INPUT-$_TSYMS_INPUT"
    ["BiTrue"]="https://openapi.bitrue.com/api/v1/ticker/price?symbol=$_FSYM_INPUT$_TSYMS_INPUT"
    )
    
    #for i in "${!_apiurl[@]}"; do
    #  echo "API Provider: $i with URL ${_apiurl[$i]}"
    #  echo "---------------------------------------"
    #done

    #_apiurl_len=${#_apiurl[@]}
    #echo $_apiurl_len

    echo
    echo "          Select the number for the API Provider you wish to use "
    echo

    # Capture user input & call job creation function
    select _api in ${!_apiurl[@]} "QUIT" 
    do
        case "$_api" in
            Cryptocompare) echo; echo "   API Option: $_api" ; FETCH_URL=${_apiurl[$_api]}; FUNC_CREATE_JOB; break ;;
            KuCoin) echo; echo "   API Option: $_api" ; FETCH_URL=${_apiurl[$_api]}; FUNC_CREATE_JOB; break ;;
            BiTrue) echo; echo "   API Option: $_api" ; FETCH_URL=${_apiurl[$_api]}; FUNC_CREATE_JOB; break ;;
            "QUIT") echo "exiting now..." ; FUNC_EXIT; break ;;
            *) echo invalid option;;
        esac
    done

}


FUNC_GET_INPUTS;