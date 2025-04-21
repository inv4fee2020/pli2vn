#!/bin/bash

# Get current user id and store as var
USER_ID=$(getent passwd $EUID | cut -d: -f1)

# Authenticate sudo perms before script execution to avoid timeouts or errors
sudo -l > /dev/null 2>&1

# Set Colour Vars
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

if [ -e ~/"plinode_$(hostname -f)".vars ]; then
    source ~/"plinode_$(hostname -f)".vars
fi

if [ -e ~/"plinode_$(hostname -f)"_bkup.vars ]; then
    source ~/"plinode_$(hostname -f)"_bkup.vars
fi



FUNC_RESTORE_DECRYPT(){
    #set -x
    PLI_VARS_FILE="plinode_$(hostname -f)".vars
    #echo $PLI_VARS_FILE
    if [[ ! -e ~/$PLI_VARS_FILE ]]; then
        read -r -p "please enter the previous systems .env.password key : " PASS_KEYSTORE
    fi

    if [ -e ~/"plinode_$(hostname -f)".vars ]; then
    source ~/"plinode_$(hostname -f)".vars
    fi

    RESTORE_FILE=""
    RESTORE_FILE=$(echo $BACKUP_FILE | sed 's/\.[^.]*$//')
    
    gpg --batch --yes --passphrase=$PASS_KEYSTORE -o $RESTORE_FILE --decrypt $BACKUP_FILE  > /dev/null 2>&1 
    echo $?

    if [[ $? -gt 128 ]]; then
        echo
        echo -e "${RED}ERROR :: There was a problem with the entered KeyStore password... please check${NC}"
        echo
        FUNC_EXIT_ERROR;
    fi      

    ##set +x

    if [[ "$BACKUP_FILE" =~ "plugin_mainnet_db" ]]; then
        #echo "matched 'contains' db name..."
        FUNC_RESTORE_DB
    elif [[ "$BACKUP_FILE" =~ "conf_vars" ]]; then
        #echo "else returned so must be file restore..."
        FUNC_RESTORE_CONF
    fi

    sudo chown $USER_ID\:$DB_BACKUP_GUSER -R "/$DB_BACKUP_DIR"
    if [[ ! -e "$RESTORE_FILE" ]]; then
    echo -e "{$RED}DECRYPT ERROR :: Restore file does not exist"
    FUNC_EXIT_ERROR;
    fi

    FUNC_EXIT;

}

FUNC_RESTORE_DB(){

    FUNC_DB_DR_CHECK
    
    if [ -e ~/"plinode_$(hostname -f)".vars ]; then
        source ~/"plinode_$(hostname -f)".vars
    fi

    ### removes last extension suffix to get next file name
    RESTORE_FILE_SQL=$(echo "$RESTORE_FILE" | sed -e 's/\.[^.]*$//')
    
    sudo chown $USER_ID\:$DB_BACKUP_GUSER -R "/$DB_BACKUP_DIR"


    if [[ ! -e "$RESTORE_FILE" ]]; then
    echo -e "${RED}ERROR :: DB Restore file does not exist${NC}"
    FUNC_EXIT_ERROR;
    fi

    echo "   DB RESTORE.... unzip file name: $RESTORE_FILE"
    gunzip -vdf $RESTORE_FILE > /dev/null 2>&1
    sudo chown $USER_ID\:$DB_BACKUP_GUSER -R "$RESTORE_FILE_SQL"
    sleep 2


    echo "   DB RESTORE.... psql file name: $RESTORE_FILE_SQL"
    sudo su postgres -c "export PGPASSFILE="$DB_BACKUP_PATH/.pgpass"; psql -d $DB_NAME < $RESTORE_FILE_SQL" > /dev/null 2>&1
    sleep 2
    
    echo "   DB RESTORE.... restarting service postgresql"
    sudo systemctl restart postgresql
    echo
    echo 
    echo "   DB RESTORE.... restarting plugin node"
    sudo pm2 restart all
    sleep 2


    echo "   DB RESTORE.... waiting for API to respond"
    until $(curl --output /dev/null --silent --head --fail http://localhost:6688); do
        printf '.'
        sleep 5
    done
   
    echo           
    echo "   DB RESTORE.... API connection responding - continuing"
    echo
    echo       
    ### NOTE: .pgpass file would need to be manually re-created inorder to restore files? As would the .env.password keystore
    shred -uz -n 1 $RESTORE_FILE_SQL > /dev/null 2>&1
    echo
    echo
    echo "   DB RESTORE - COMPLETED"
    echo

    FUNC_EXIT
}


FUNC_RESTORE_CONF(){

    if [[ ! -e "$RESTORE_FILE" ]]; then
    echo -e "${RED}ERROR :: CONF Restore file does not exist${NC}"
        FUNC_EXIT_ERROR;
    fi

    RESTORE_FILE_CONF=$(echo "$RESTORE_FILE" | sed -e 's/\.[^.]*$//')
    echo "   CONFIG FILES RESTORE...."

    echo "   uncompressing gz file: $RESTORE_FILE"
    gunzip -df $RESTORE_FILE > /dev/null 2>&1
    #sleep 2

    echo "   unpacking tar file: $RESTORE_FILE_CONF"
    tar -xvf $RESTORE_FILE_CONF --directory=/
    sleep 2

    shred -uz -n 1 $RESTORE_FILE $RESTORE_FILE_CONF > /dev/null 2>&1
    FUNC_EXIT
}


FUNC_EXIT(){
	exit 0
	}


FUNC_EXIT_ERROR(){
	exit 1
}


FUNC_RESTORE_MENU(){
    ### Call the setup script to set permissions & check installed pkgs
    bash _plinode_setup_bkup.sh > /dev/null 2>&1

    node_backup_arr=()
    BACKUP_FILE=$'\n' read -r -d '' -a node_backup_arr < <( find /plinode_backups/ -type f -name *.gpg | head -n 8 | sort -z )
    node_backup_arr_len=${#node_backup_arr[@]}

    echo
    echo "          Showing last 8 backup files. "
    echo "          Select the number for the file you wish to restore "
    echo

    select _file in "${node_backup_arr[@]}" "QUIT" 
    do
        case $_file in
            ${node_backup_arr[0]}) echo "   RESTORE MENU - Restoring file: ${node_backup_arr[0]}" ; BACKUP_FILE="${node_backup_arr[0]}"; FUNC_RESTORE_DECRYPT; break ;;
            ${node_backup_arr[1]}) echo "   RESTORE MENU - Restoring file: ${node_backup_arr[1]}" ; BACKUP_FILE="${node_backup_arr[1]}"; FUNC_RESTORE_DECRYPT; break ;;
            ${node_backup_arr[2]}) echo "   RESTORE MENU - Restoring file: ${node_backup_arr[2]}" ; BACKUP_FILE="${node_backup_arr[2]}"; FUNC_RESTORE_DECRYPT; break ;;
            ${node_backup_arr[3]}) echo "   RESTORE MENU - Restoring file: ${node_backup_arr[3]}" ; BACKUP_FILE="${node_backup_arr[3]}"; FUNC_RESTORE_DECRYPT; break ;;
            ${node_backup_arr[4]}) echo "   RESTORE MENU - Restoring file: ${node_backup_arr[4]}" ; BACKUP_FILE="${node_backup_arr[4]}"; FUNC_RESTORE_DECRYPT; break ;;
            ${node_backup_arr[5]}) echo "   RESTORE MENU - Restoring file: ${node_backup_arr[5]}" ; BACKUP_FILE="${node_backup_arr[5]}"; FUNC_RESTORE_DECRYPT; break ;;
            ${node_backup_arr[6]}) echo "   RESTORE MENU - Restoring file: ${node_backup_arr[6]}" ; BACKUP_FILE="${node_backup_arr[6]}"; FUNC_RESTORE_DECRYPT; break ;;
            ${node_backup_arr[7]}) echo "   RESTORE MENU - Restoring file: ${node_backup_arr[7]}" ; BACKUP_FILE="${node_backup_arr[7]}"; FUNC_RESTORE_DECRYPT; break ;;
            "QUIT") echo "exiting now..." ; FUNC_EXIT; break ;;
            *) echo invalid option;;
        esac
    done

}


FUNC_DB_DR_CHECK(){

    echo -e "${GREEN}       ######################################################################################${NC}"
    echo -e "${GREEN}       ######################################################################################${NC}"
    echo -e "${GREEN}       ##${NC}"
    echo -e "${GREEN}       ##      RESTORE SCENARIO CONFIRMATION...${NC}"
    echo -e "${GREEN}       ##${NC}"   

    # Ask the user acc for login details (comment out to disable)
    #DR_RESTORE=false
        while true; do
            echo -e "${GREEN}       ##${NC}"
            echo -e "${GREEN}       ##  A Full Restore is ONLY where you have moved backup files to a FRESH / NEW VPS host${NC}"
            echo -e "${GREEN}       ##  this includes where you have reset your previous VPS installation to start again..${NC}"
            echo -e "${GREEN}       ##${NC}"
            echo
            read -t30 -r -p "       Are you performing a Full Restore to BLANK / NEW VPS? - Please answer (Y)es or (N)o : " _RES_INPUT
            if [ $? -gt 128 ]; then
                #clear
                echo
                echo
                echo "      ....timed out waiting for user response - please select a file to restore..."
                echo
                #DR_RESTORE=false
                FUNC_RESTORE_MENU;
                break
            fi
            case $_RES_INPUT in
                [Yy][Ee][Ss]|[Yy]* ) 
                    DR_RESTORE=true     #flag used to involke the EI REBUID FUNC
                    break
                    ;;
                [Nn][Oo]|[Nn]* ) 
                    #FUNC_RESTORE_MENU
                    DR_RESTORE=false
                    echo
                    break
                    ;;
                * ) echo "Please answer (y)es or (n)o.";;
            esac
        done
}

FUNC_RESTORE_MENU;    