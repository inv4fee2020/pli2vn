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
    echo -e "#   This script generates the necessary toml blob for the Job-Setup section in the docs"
    echo -e "#   source: https://docs.goplugin.co/oracle/job-setup"
    echo -e "#"
    echo -e "#   The script removes the "-" hyphen from the original returned 'external_job_id' value"
    echo -e "#"
    echo -e "#   The script checks for leading  / trailing white spaces and removes as necessary"
    echo -e "#   & converts the 'xdc' prefix to '0x' as necessary"
    echo -e "#"
    echo -e "#${NC}"
    sleep 0.5s
    #source ~/"plinode_$(hostname -f)".vars

    read -p 'Enter FROM Pair (fsym) ticker : ' _FYSM_INPUT
    read -p 'Enter TO Pair (tsyms) ticker : ' _TYSMS_INPUT
    echo "-----------------------------------------------"
    read -p 'Enter your Oracle Contract Address : ' _INPUT
    ORACLE_ADDR="$(echo $_INPUT | sed '/^$/d;/^\\\s*$/d;s/^xdc/0x/g')"
    #FETCH_URL="https://min-api.cryptocompare.com/data/price?fsym=$_FYSM_INPUT&tsyms=$_TYSMS_INPUT"
    FUNC_API_MENU;
}


FUNC_CREATE_JOB(){

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

    plugin admin login -f $PLI_DEPLOY_PATH/apicredentials.txt > /dev/null 2>&1
    if [ $? != 0 ]; then
      echo
      echo  -e "${RED}## ERROR :: Plugin admin login encoutered issues${NC}"
      sleep 2s
      exit
    else
      echo -e "${GREEN}INFO :: Successfully logged in with API credentials${NC}"
      sleep 0.5s
    fi
    echo
    plugin jobs create ~/$JOB_FNAME > /tmp/plivn_job_id.raw
    if [ $? != 0 ]; then
      echo
      echo  -e "${RED}## ERROR :: Plugin JOBS creation encoutered issues${NC}"
      sleep 2s
      exit
    else
      echo -e "${GREEN}INFO :: Successfully created JOB ID $JOB_TITLE ${NC}"
      sleep 0.5s
    fi
    #echo
    ext_job_id_raw="$(sudo -u postgres -i psql -d plugin_mainnet_db -t -c "SELECT external_job_id FROM jobs WHERE name = '$JOB_TITLE';")"
    ext_job_id=$(echo $ext_job_id_raw | tr -d \-)
    echo -e "${GREEN}---------------------------------------------------------------"
    echo
    echo -e "       Local node job id - Copy to your Solidity script"
    echo -e "================================================================="
    echo -e 
    echo -e "Oracle Contract Address is :   $ORACLE_ADDR"
    echo -e "Job $JOB_TITLE ID is :   $ext_job_id "
    echo 
    echo -e "URL for APIConsumer is :   $FETCH_URL${NC}"
  }



FUNC_EXIT(){
	exit 0
	}


FUNC_EXIT_ERROR(){
	exit 1
}
  



FUNC_API_MENU(){

    ## https://linuxhint.com/associative_array_bash/

    ### Call the setup script to set permissions & check installed pkgs
    #bash _plinode_setup_bkup.sh > /dev/null 2>&1

    # FETCH_URL="https://min-api.cryptocompare.com/data/price?fsym=$_FYSM_INPUT&tsyms=$_TYSMS_INPUT"

    
    declare -A _apiurl=( 
    ['Cryptocompare']="https://min-api.cryptocompare.com/data/price?fsym=$_FYSM_INPUT&tsyms=$_TYSMS_INPUT"
    ['KuCoin']="https://api.kucoin.com/api/v1/market/orderbook/level1?symbol=$_FYSM_INPUT-$_TYSMS_INPUT"
    ['BiTrue']="https://openapi.bitrue.com/api/v1/ticker/price?symbol=$_FYSM_INPUT$_TYSMS_INPUT"
    )


    #node_backup_arr=()
    #BACKUP_FILE=$'\n' read -r -d '' -a node_backup_arr < <( find /plinode_backups/ -type f -name *.gpg | head -n 8 | sort -z )
    #node_backup_arr+=(quit)
    #echo ${_apiurl[@]}
    
    for i in "${!_apiurl[@]}"; do
      echo "API Provider: $i with URL ${_apiurl[@]}"
    done

    #declare -a opt_api=()
    #declare -A opt_url=()
#
    #for i in "${!_apiurl[@]}"; do
    #  opt_api[$i]="${options[$i]%% *}"
    #  opt_url[${opt_api[$i]}]="${_apiurl[$i]#* }"
    #done


    _apiurl_len=${#_apiurl[@]}
    echo $_apiurl_len

    echo
    echo "          Select the number for the API Provider you wish to use "
    echo

    select _api in "${_apiurl[@]}" "QUIT" 
    do
        case "$_api" in
            ${!_apiurl[0]}) echo "   API Option: ${!_apiurl[0]}" ; FETCH_URL="${_apiurl[$_api]}"; FUNC_CREATE_JOB; break ;;
            ${!_apiurl[1]}) echo "   API Option: ${!_apiurl[1]}" ; FETCH_URL="${_apiurl[$_api]}"; FUNC_CREATE_JOB; break ;;
            ${!_apiurl[2]}) echo "   API Option: ${!_apiurl[2]}" ; FETCH_URL="${_apiurl[$_api]}"; FUNC_CREATE_JOB; break ;;
            "QUIT") echo "exiting now..." ; FUNC_EXIT; break ;;
            *) echo invalid option;;
        esac
    done

}

####  #!/usr/bin/env bash
####  
####  declare -a opt_host=()   # Initialize our arrays, to make sure they're empty.
####  declare -A opt_ip=()     # Note that associative arrays require Bash version 4.
####  
####  for i in "${!options[@]}"; do
####    opt_host[$i]="${options[$i]%% *}"             # create an array of just names
####    opt_ip[${opt_host[$i]}]="${options[$i]#* }"   # map names to IPs
####  done
####  
####  PS3='Please enter your choice (q to quit): '
####  select host in "${opt_host[@]}"; do
####    case "$host" in
####      "") break ;;  # This is a fake; any invalid entry makes $host=="", not just "q".
####      *) ssh "${opt_ip[$host]}" ;;
####    esac
####  done


FUNC_GET_INPUTS;