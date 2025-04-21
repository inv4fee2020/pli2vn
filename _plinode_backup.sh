#!/bin/bash

# Authenticate sudo perms before script execution to avoid timeouts or errors
sudo -l > /dev/null 2>&1

# Set Colour Vars
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get current user id and store as var
USER_ID=$(getent passwd $EUID | cut -d: -f1)
GROUP_ID=$(getent group $EUID | cut -d: -f1)

if [ -e ~/"plinode_$(hostname -f)".vars ]; then
    source ~/"plinode_$(hostname -f)".vars
fi

FUNC_DB_VARS(){
    ## VARIABLE / PARAMETER DEFINITIONS
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


    PLI_DB_VARS_FILE="plinode_$(hostname -f)"_bkup.vars
    if [ ! -e ~/$PLI_DB_VARS_FILE ]; then
        #clear
        echo
        echo
        echo -e "${GREEN} #### NOTICE: No backup VARIABLES file found.. ####${NC}"
        echo
        echo -e "${GREEN} ..creating local backup vars file '$HOME/$PLI_DB_VARS_FILE' ${NC}"
        cp -n sample_bkup.vars ~/$PLI_DB_VARS_FILE
        chmod 600 ~/$PLI_DB_VARS_FILE
        echo
    fi
    source ~/$PLI_DB_VARS_FILE
}



FUNC_CHECK_DIRS(){

    # Checks if NOT NULL for the 'DB_BACKUP_DIR'variable
    if [ ! -z "$DB_BACKUP_DIR" ] ; then
        DB_BACKUP_DIR="plinode_backups"
    
        # Checks if directory exists & creates if not + sets perms
        # following logic attempts to resolve the leading Root '/' path issue
    
        if [ ! -d "/$DB_BACKUP_DIR" ]; then
            sudo mkdir "/$DB_BACKUP_DIR"
            sudo chown $USER_ID\:$DB_BACKUP_GUSER -R "/$DB_BACKUP_DIR"
            sudo chmod g+rw "/$DB_BACKUP_DIR";
        fi
    else
        DB_BACKUP_DIR="plinode_backups"
        # adds the variable value to the VARS file
        sed -i.bak 's/DB_BACKUP_DIR=\"\"/DB_BACKUP_DIR=\"'$DB_BACKUP_DIR'\"/g' ~/$PLI_DB_VARS_FILE
    fi

    # Checks if directory exists & creates if not + sets perms
    
    if [ ! -d "/$DB_BACKUP_DIR" ]; then
        sudo mkdir "/$DB_BACKUP_DIR"
        sudo chown $USER_ID\:$DB_BACKUP_GUSER -R "/$DB_BACKUP_DIR"
        sudo chmod g+rw "/$DB_BACKUP_DIR";
    fi
        
    # Updates the 'DB_BACKUP_PATH' & 'DB_BACKUP_OBJ' variable
    DB_BACKUP_PATH="/$DB_BACKUP_DIR"
    sudo chown $USER_ID\:$DB_BACKUP_GUSER -R "/$DB_BACKUP_DIR"
    sudo chmod g+rw "/$DB_BACKUP_DIR"


    ###  Based on the above changes in values originally read form var file
    ###  we then update the other vars to reflect these changes so the whole
    ###  script execution reflects these updates

    DB_BACKUP_OBJ="$DB_BACKUP_PATH/$DB_BACKUP_FNAME"
    CONF_BACKUP_OBJ="$DB_BACKUP_PATH/$NODE_BACKUP_FNAME"
    echo "checking vars - your configured node backup PATH is: $DB_BACKUP_PATH"
    sleep 2s

}




FUNC_DB_PRE_CHECKS(){
    # check that necessary user / groups are in place 
    
    #check DB_BACKUP_FUSER values
    if [ -z "$DB_BACKUP_FUSER" ]; then
        export DB_BACKUP_FUSER="$USER_ID"
        # adds the variable value to the VARS file
        sed -i.bak 's/DB_BACKUP_FUSER=\"\"/DB_BACKUP_FUSER=\"'$USER_ID'\"/g' ~/$PLI_DB_VARS_FILE
    fi
    
    # check shared group '$DB_BACKUP_GUSER' exists & set permissions
        sudo groupadd nodebackup > /dev/null 2>&1
    
        # adds the variable value to the VARS file
        sed -i.bak 's/DB_BACKUP_GUSER=\"\"/DB_BACKUP_GUSER=\"nodebackup\"/g' ~/$PLI_DB_VARS_FILE
        DB_BACKUP_GUSER="nodebackup"
    
    # add users to the group
    if [ ! -z "$GD_FUSER" ]; then
        DB_GUSER_MEMBER=(postgres $USER_ID $GD_FUSER)
    else
        GD_ENABLED=false
        DB_GUSER_MEMBER=(postgres $USER_ID)
    fi
    
    
    
    #echo "pre-check vars - assiging user-group permissions.."
    for _user in "${DB_GUSER_MEMBER[@]}"
    do
        hash $_user &> /dev/null
        sudo usermod -aG "$DB_BACKUP_GUSER" "$_user" > /dev/null 2>&1
    done 
    
    sleep 2s
}







FUNC_CONF_BACKUP_LOCAL(){

    ### Call the setup script to set permissions & check installed pkgs
    bash _plinode_setup_bkup.sh > /dev/null 2>&1

    
    FUNC_DB_VARS
    FUNC_DB_PRE_CHECKS  # order is specific as pre checks for user/groups which are assigned to dirs 
    FUNC_CHECK_DIRS
    tar -cvpzf $CONF_BACKUP_OBJ ~/plinode* > /dev/null 2>&1

    FUNC_CONF_BACKUP_ENC

    if [ "$_OPTION" == "-full" ]; then
        FUNC_DB_BACKUP_LOCAL
    fi

    FUNC_EXIT;

}


FUNC_DB_BACKUP_LOCAL(){
    if [ "$_OPTION" == "-db" ]; then

        ### Call the setup script to set permissions & check installed pkgs
        bash _plinode_setup_bkup.sh

        FUNC_DB_VARS
        FUNC_DB_PRE_CHECKS
        FUNC_CHECK_DIRS
    fi

    # checks if the '.pgpass' credentials file exists - if not creates in home folder & copies to dest folder
    # & sets perms

    if [ ! -e ~/.pgpass ]; then
cat <<EOF > ~/.pgpass
Localhost:5432:$DB_NAME:postgres:$DB_PWD_NEW
EOF
    fi

        cp -p ~/.pgpass $DB_BACKUP_PATH/.pgpass
        sudo chown postgres:postgres $DB_BACKUP_PATH/.pgpass
        sudo chmod 600 $DB_BACKUP_PATH/.pgpass
        sleep 2s
        

    echo "local backup - running pgdump db backup process"

    # switch to 'postgres' user and run command to create inital sql dump file
    sudo su postgres -c "export PGPASSFILE="$DB_BACKUP_PATH/.pgpass"; pg_dump -c -w -U postgres $DB_NAME | gzip > $DB_BACKUP_OBJ"  > /dev/null 2>&1
    
    echo "local backup - successfully created unencrypted compressed gz DB file:  "$DB_BACKUP_OBJ""
    sudo chown $DB_BACKUP_FUSER:$DB_BACKUP_GUSER $DB_BACKUP_OBJ
    
    # Calls the file encryption 
    FUNC_DB_BACKUP_ENC;
    
    
    # check menu selection & that remote backup software configured
    # GD_ENABLED set in FUNC_DB_PRE_CHECKS
    if [ "$_OPTION" == "-full" ] && [ "$GD_ENABLED" == "true" ]; then
        FUNC_DB_BACKUP_REMOTE
    fi

    sudo rm -f $DB_BACKUP_PATH/.pgpass
    sleep 2s
    FUNC_EXIT;
}


FUNC_DB_BACKUP_ENC(){

    # runs GnuPG or gpg to encrypt the sql dump file - uses main keystore password as secret
    # outputs file to new folder ready for upload

    if [ -e $DB_BACKUP_OBJ ]; then
        sudo gpg --yes --batch --passphrase=$PASS_KEYSTORE -o $ENC_PATH/$ENC_FNAME -c $DB_BACKUP_OBJ
        error_exit;
        echo "local backup - successfully created encrypted gpg DB file:  "$ENC_FNAME""
        sudo chown $DB_BACKUP_FUSER:$DB_BACKUP_GUSER $ENC_PATH/$ENC_FNAME
        echo "local backup - securely erased unencrypted compressed gz DB file:  "$DB_BACKUP_OBJ""
        shred -uz -n 1 $DB_BACKUP_OBJ
    fi
}




FUNC_CONF_BACKUP_ENC(){

    if [ -e $CONF_BACKUP_OBJ ]; then
        sudo gpg --yes --batch --passphrase=$PASS_KEYSTORE -o $ENC_PATH/$ENC_CONFNAME -c $CONF_BACKUP_OBJ
        error_exit;
        echo "local backup - successfully created encrypted gpg conf file:  "$ENC_CONFNAME""
        sudo chown $DB_BACKUP_FUSER:$DB_BACKUP_GUSER $ENC_PATH/$ENC_CONFNAME
        echo "local backup - securely erase unencrypted conf file:  "$CONF_BACKUP_OBJ""
        shred -uz -n 1 $CONF_BACKUP_OBJ 
    fi
}


FUNC_DB_BACKUP_REMOTE(){

    if [ "$_OPTION" == "-remote" ]; then
        FUNC_DB_VARS
    fi

    # add check that gupload is installed!
    # switches to gupload user to run cmd to upload encrypted file to your google drive - skips existing files

    # add check for user account & installation

    sudo su gdbackup -c "cd ~/; .google-drive-upload/bin/gupload -q -d /$DB_BACKUP_PATH/*.gpg -C $(hostname -f) --hide"
    error_exit;
}


FUNC_SCP_CMD(){

    # Provide SCP commands to connect to the VPS and download backups

    echo
    echo
    echo -e "${GREEN}   The SCP commands to copy your Plugin node backup files is as follows:${NC}"
    echo
    keys_arr=()
    CPORT=$(sudo ss -tlpn | grep sshd | awk '{print$4}' | cut -d ':' -f 2 -s)

    if [ -s "$HOME/.ssh/authorized_keys" ] && [ $CPORT != "22" ]; then
        echo -e "${GREEN}               INFO :: ssh-keys & non-std ssh port detected"
        echo
        echo -e "${GREEN}   NOTE :: The following command(s) are based on the # of keys detected on this system"
        echo -e "${GREEN}   NOTE :: the path to your private key file has been assumed - please update as needed"
        echo 
        IFS=$'\n' read -r -d '' -a keys_arr < <( cat ~/.ssh/authorized_keys | awk '{print$4}')
        keys_arr_len=${#keys_arr[@]}

        for (( i = 0 ; i < $keys_arr_len ; i++))
        do
            echo -e "${RED}     scp -i ~/.ssh/${keys_arr[$i]}.key -P $CPORT $USER@$(hostname -I | awk '{print $1}'):/plinode_backups/*.gpg ~/${NC}"
        done
    elif [ $CPORT != "22" ]; then
        echo -e "${GREEN}               INFO :: non-std ssh port detected: $CPORT${NC}"
        echo
        echo -e "${RED}     scp -P $CPORT $USER@$(hostname -I | awk '{print $1}'):/plinode_backups/*.gpg ~/${NC}"
    else
        echo -e "${RED}     scp $USER@$(hostname -I | awk '{print $1}'):/plinode_backups/*.gpg ~/${NC}"
    fi
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo

}



FUNC_EXIT(){
    FUNC_SCP_CMD
	exit 0
}



error_exit(){
    if [ $? != 0 ]; then
        #echo
        echo "ERROR - Exiting early"
        exit 1
    else
        return
    fi
}



case "$1" in
        -full)
                _OPTION="-full"
                FUNC_CONF_BACKUP_LOCAL
                ;;
        -conf)
                _OPTION="-conf"
                FUNC_CONF_BACKUP_LOCAL
                ;;
        -db)
                _OPTION="-db"
                FUNC_DB_BACKUP_LOCAL
                ;;
        -scp)
                FUNC_SCP_CMD
                ;;
        *)
                #clear
                echo 
                echo 
                echo -e "${GREEN}Usage: $0 {function}${NC}"
                echo 
                echo -e "${GREEN}where {function} is one of the following;${NC}"
                echo 
                echo -e "${GREEN}      -full      ==  performs a local backup of both config & DB files only${NC}"
                echo -e "${GREEN}      -conf      ==  performs a local backup of config files only${NC}"
                echo -e "${GREEN}      -db        ==  performs a local backup of DB files only${NC}"
                echo 
                echo -e "${GREEN}      -scp       ==  displays the secure copy (scp) cmds to download backup files${NC}"
                echo 
                echo 
esac
