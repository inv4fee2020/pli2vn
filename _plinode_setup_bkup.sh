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
    fi
    source ~/$PLI_DB_VARS_FILE
}



FUNC_PKG_CHECK(){

    BKUP_PACKAGES=(gpg shred gunzip)

    for i in "${BKUP_PACKAGES[@]}"
    do
        hash $i &> /dev/null
        if [ $? -eq 1 ]; then
           #echo >&2 "package "$i" not found. installing...."
           sudo apt install -y "$i" > /dev/null 2>&1
        fi
        #echo "packages "$i" exist. proceeding...."
    done

}



FUNC_CHECK_DIRS(){

    DB_BACKUP_DIR="plinode_backups"

    if [ ! -d "/$DB_BACKUP_DIR" ]; then
        echo -e "${NC} SETTING FOLDER PERMS  ${NC}"
        sudo mkdir "/$DB_BACKUP_DIR"
    fi

    # adds the variable value to the VARS file
    sed -i.bak 's/DB_BACKUP_DIR=\"\"/DB_BACKUP_DIR=\"'$DB_BACKUP_DIR'\"/g' ~/$PLI_DB_VARS_FILE
    sudo chown $USER_ID\:$DB_BACKUP_GUSER -R "/$DB_BACKUP_DIR"
    sudo chmod g+rw "/$DB_BACKUP_DIR"
    DB_BACKUP_PATH="/$DB_BACKUP_DIR"

}




FUNC_DB_PRE_CHECKS(){
# check that necessary user / groups are in place 

#check DB_BACKUP_FUSER values
if [ -z "$DB_BACKUP_FUSER" ]; then
    export DB_BACKUP_FUSER="$USER_ID"
    sed -i.bak 's/DB_BACKUP_FUSER=\"\"/DB_BACKUP_FUSER=\"'$USER_ID'\"/g' ~/$PLI_DB_VARS_FILE
fi

# check shared group '$DB_BACKUP_GUSER' exists & set permissions
if [ -z "$DB_BACKUP_GUSER" ] && [ ! $(getent group nodebackup) ]; then
    sudo groupadd nodebackup > /dev/null 2>&1
    sed -i.bak 's/DB_BACKUP_GUSER=\"\"/DB_BACKUP_GUSER=\"nodebackup\"/g' ~/$PLI_DB_VARS_FILE
    DB_BACKUP_GUSER="nodebackup"

elif [ ! -z "$DB_BACKUP_GUSER" ] && [ ! $(getent group $DB_BACKUP_GUSER) ]; then
    sudo groupadd $DB_BACKUP_GUSER > /dev/null 2>&1
    sed -i.bak 's/DB_BACKUP_GUSER=\"\"/DB_BACKUP_GUSER=\"$DB_BACKUP_GUSER\"/g' ~/$PLI_DB_VARS_FILE
fi



# add users to the group
if [ ! -z "$GD_FUSER" ]; then
    DB_GUSER_MEMBER=(postgres $USER_ID $GD_FUSER)
else
    GD_ENABLED=false
    DB_GUSER_MEMBER=(postgres $USER_ID)
fi

for _user in "${DB_GUSER_MEMBER[@]}"
do
    hash $_user &> /dev/null
    sudo usermod -aG "$DB_BACKUP_GUSER" "$_user" > /dev/null 2>&1
done 

sleep 1s
}



error_exit()
{
    if [ $? != 0 ]; then
        #echo
        echo "ERROR - Exiting early"
        exit 1
    else
        return
    fi
}


FUNC_PKG_CHECK
FUNC_DB_VARS
FUNC_DB_PRE_CHECKS
FUNC_CHECK_DIRS
echo "COMPLETED BACKUP SETUP SCRIPT"