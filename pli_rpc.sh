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


FUNC_RPC_MENU(){

        while true; do
            echo -e "${GREEN}       ##${NC}"
            echo -e "${GREEN}       ##  This script changes the WS & RPC server configuration based on the selected option ${NC}"
            echo -e "${GREEN}       ##  below. The script will overwrite the existing values with those of the selected option ..${NC}"
            echo -e "${GREEN}       ##${NC}"
            echo
            echo -e "${GREEN}       ##  1 -- Set to 'pli.xdcrpc' option ${NC}"
            echo -e "${GREEN}       ##  2 -- Set to 'blocksscan' option ${NC}"
            echo -e "${GREEN}       ##  3 -- Set to 'icotokens' option ${NC}"
            echo -e "${GREEN}       ##  4 -- Set to 'pliws.xdcrpc' option ${NC}"
            echo
            read -t30 -r -p "       Enter the option NUMBER from the list above : " _RES_INPUT
            if [ $? -gt 128 ]; then
                echo
                echo
                echo "      ....timed out waiting for user response - please select a NUMBER from the list... exiting"
                echo
                FUNC_EXIT_ERROR
            fi
            case $_RES_INPUT in
                1* ) 
                    VARVAL_RPC="https://pli.xdcrpc.com"
                    VARVAL_WSS="wss://pli.xdcrpc.com/ws"
                    break
                    ;;
                2* ) 
                    VARVAL_RPC="https://plirpc.blocksscan.io"
                    VARVAL_WSS="wss://pluginws.blocksscan.io"
                    break
                    ;;
                3* ) 
                    VARVAL_RPC="https://plixdcrpc.icotokens.net"
                    VARVAL_WSS="wss://plixdcwss.icotokens.net"
                    break
                    ;;
                4* ) 
                    VARVAL_RPC="https://pliws.xdcrpc.com"
                    VARVAL_WSS="wss://pliws1.xdcrpc.com"
                    break
                    ;;
                * ) echo -e "${RED}  please select a NUMBER from the list${NC}";;
            esac
        done
        FUNC_SED_FILE;
}

 


FUNC_SED_FILE(){

    echo "updating $BASH_FILE3 with selected option...."
    sleep 2s

    sed  -i 's|^wsUrl.*|wsUrl = '\"$VARVAL_WSS\"'|g' $PLI_DEPLOY_PATH/$BASH_FILE3
    cat $PLI_DEPLOY_PATH/$BASH_FILE3 | grep wsUrl

    sed  -i 's|^httpUrl.*|httpUrl = '\'$VARVAL_RPC\''|g' $PLI_DEPLOY_PATH/$BASH_FILE3
    cat $PLI_DEPLOY_PATH/$BASH_FILE3 | grep httpUrl


    echo "restarting node process...."
    sleep 2s

    pm2 restart all
    pm2 reset all
    pm2 list

}


FUNC_EXIT_ERROR(){
	exit 1
}

FUNC_RPC_MENU;
