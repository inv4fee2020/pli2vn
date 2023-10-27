#!/bin/bash


# Get current user id and store as var
USER_ID=$(getent passwd $EUID | cut -d: -f1)

# Authenticate sudo perms before script execution to avoid timeouts or errors
sudo -l > /dev/null 2>&1

# Set the sudo timeout for USER_ID to expire on reboot instead of default 5mins
echo "Defaults:$USER_ID timestamp_timeout=-1" > /tmp/plisudotmp
sudo sh -c 'cat /tmp/plisudotmp > /etc/sudoers.d/plinode_deploy'

# Set Colour Vars
GREEN='\033[0;32m'
#RED='\033[0;31m'
RED='\033[0;91m'  # Intense Red
YELLOW='\033[0;33m'
BYELLOW='\033[1;33m'
NC='\033[0m' # No Color

FDATE=$(date +"%Y_%m_%d_%H_%M")



FUNC_VARS(){
## VARIABLE / PARAMETER DEFINITIONS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


    PLI_VARS_FILE="plinode_$(hostname -f)".vars
    if [ ! -e ~/$PLI_VARS_FILE ]; then
        #clear
        echo
        echo -e "${RED} #### NOTICE: No VARIABLES file found. ####${NC}"
        echo -e "${RED} ..creating local vars file '$HOME/$PLI_VARS_FILE' ${NC}"

        cp sample.vars ~/$PLI_VARS_FILE
        chmod 600 ~/$PLI_VARS_FILE

        echo
        echo -e "${GREEN}nano '~/$PLI_VARS_FILE' ${NC}"
        #sleep 2s
    fi

    source ~/$PLI_VARS_FILE

    if [[ "$CHECK_PASSWD" == "true" ]]; then
        FUNC_PASSWD_CHECKS
    fi

}



FUNC_PKG_CHECK(){

    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## CHECK NECESSARY PACKAGES HAVE BEEN INSTALLED...${NC}"

    for i in "${REQ_PACKAGES[@]}"
    do
        hash $i &> /dev/null
        if [ $? -eq 1 ]; then
           echo >&2 "package "$i" not found. installing...."
           sudo apt install -y "$i"
        fi
        echo "packages "$i" exist. proceeding...."
    done

}



FUNC_VALUE_CHECK(){

    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## CONFIRM SCRIPTS VARIABLES FILE HAS BEEN UPDATED...${NC}"

    # Ask the user acc for login details (comment out to disable)
    CHECK_PASSWD=false
        while true; do
            read -t7 -r -p "please confirm that you have updated the vars file with your values ? (Y/n) " _input
            if [ $? -gt 128 ]; then
                echo
                echo "timed out waiting for user response - proceeding as normal..."
                CHECK_PASSWD=true
                FUNC_NODE_DEPLOY;
            fi
            case $_input in
                [Yy][Ee][Ss]|[Yy]* ) 
                    CHECK_PASSWD=true
                    FUNC_NODE_DEPLOY
                    break
                    ;;
                [Nn][Oo]|[Nn]* ) 
                    FUNC_EXIT
                    ;;
                * ) echo "Please answer (y)es or (n)o.";;
            esac
        done
}




FUNC_PASSWD_CHECKS(){
    # check all credentials has been updated - if not auto gen
    
    SAMPLE_KEYSTORE='$oM3$tr*nGp4$$w0Rd$'
    # PASS_KEYSTORE value to compare against

    SAMPLE_DB_PWD="testdbpwd1234"
    # DB_PWD_NEW value to compare against
    
    
    SAMPLE_API_EMAIL="user123@gmail.com"
    # API EMAIL value to compare against
    
    SAMPLE_API_PASS='passW0rd123'
    # API PASSWORD value to compare against

    if ([ -z "$PASS_KEYSTORE" ] || [ "$PASS_KEYSTORE" == "$SAMPLE_KEYSTORE" ]); then
    
    echo 
    echo -e "${GREEN}     VARIABLE 'PASS_KEYSTORE' NOT UPDATED MANUALLY - AUTO GENERATING VALUE NOW"
    sleep 2s

    _AUTOGEN_KEYSTORE="'$(./gen_passwd.sh -keys)'"
    sed -i 's/^PASS_KEYSTORE.*/PASS_KEYSTORE='"$_AUTOGEN_KEYSTORE"'/g' ~/"plinode_$(hostname -f)".vars
    PASS_KEYSTORE=$_AUTOGEN_KEYSTORE
    fi


    if ([ -z "$DB_PWD_NEW" ] || [ "$DB_PWD_NEW" == "$SAMPLE_DB_PWD" ]); then
    echo 
    echo -e "${GREEN}     VARIABLE 'DB_PWD_NEW' NOT UPDATED MANUALLY - AUTO GENERATING VALUE NOW"
    sleep 2s

    _AUTOGEN_DB_PWD="$(./gen_passwd.sh -db)"
    sed -i 's/^DB_PWD_NEW.*/DB_PWD_NEW=\"'"${_AUTOGEN_DB_PWD}"'\"/g' ~/"plinode_$(hostname -f)".vars
    DB_PWD_NEW=$_AUTOGEN_DB_PWD
    fi


    if ([ -z "$API_EMAIL" ] || [ "$API_EMAIL" == "$SAMPLE_API_EMAIL" ]); then
    
    echo 
    echo -e "${GREEN}     VARIABLE 'API_EMAIL' NOT UPDATED MANUALLY - AUTO GENERATING VALUE NOW"
    sleep 2s

    _AUTOGEN_API_USER=$(tr -cd A-Za-z < /dev/urandom | fold -w10 | head -n1)
    API_EMAIL_NEW="$_AUTOGEN_API_USER@plinode.local"
    sed -i 's/^API_EMAIL.*/API_EMAIL=\"'"${API_EMAIL_NEW}"'\"/g' ~/"plinode_$(hostname -f)".vars
    API_EMAIL=$API_EMAIL_NEW
    fi



    if ([ -z "$API_PASS" ] || [ "$API_PASS" == "$SAMPLE_API_PASS" ]); then

    echo 
    echo -e "${GREEN}     VARIABLE 'API_PASS' NOT UPDATED MANUALLY - AUTO GENERATING VALUE NOW${NC}"
    echo
    sleep 2s

    _AUTOGEN_API_PWD="'$(./gen_passwd.sh -api)'"
    sed -i 's/^API_PASS.*/API_PASS='"${_AUTOGEN_API_PWD}"'/g' ~/"plinode_$(hostname -f)".vars
    API_PASS=$_AUTOGEN_DB_PWD
    fi

    # Update the system memory with the newly updated variables
    source ~/"plinode_$(hostname -f)".vars

}



FUNC_NODE_DEPLOY(){
    
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}${NC}"
    echo -e "${GREEN}             GoPlugin 2.0 ${BYELLOW}$_OPTION${GREEN} Validator Node - Install${NC}"
    echo -e "${GREEN}${NC}"
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}#########################################################################${NC}"
    sleep 3s
    # Set working directory to user home folder
    #cd ~/


    # loads variables 
    FUNC_VARS;

    # call base_sys_setup script to perform basic system updates etc.
    bash base_sys_setup.sh -D

    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## Install: check credentials are updated against default sample values...${NC}"
    FUNC_PASSWD_CHECKS;

    # installs default packages listed in vars file
    FUNC_PKG_CHECK;

    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## Install: GO & NVM Packages...${NC}"



    # SQL Install

    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## Install: POSTGRES DB ${NC}"

    cd ~/
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/pgdg.asc &>/dev/null

    sudo apt install -y postgresql postgresql-client
    sudo systemctl start postgresql.service

    sudo -u postgres -i psql -c "CREATE DATABASE $DB_NAME;"
    if [ $? -eq 0 ]; then
    	echo -e "${GREEN}## POSTGRES : plugin_db creation SUCCESSFUL ##${NC}"
        sleep 2s
    else
    	echo -e "${RED}## POSTGRES : plugin_db creation FAILED ##${NC}"
        sleep 2s
        FUNC_EXIT_ERROR
    fi

    sudo -u postgres -i psql -c "ALTER USER postgres WITH PASSWORD '$DB_PWD_NEW';"
    if [ $? -eq 0 ]; then
    	echo -e "${GREEN}## POSTGRES : plugin_db password update SUCCESSFUL ##${NC}"
        sleep 2s
    else
    	echo -e "${RED}## POSTGRES : plugin_db password update FAILED ##${NC}"
        sleep 2s
        FUNC_EXIT_ERROR
    fi



    # Install GO package

    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## Install: GOLANG Package(s) fetch & install... ${NC}"
    sleep 1s

    GO_TAR="go1.20.6.linux-amd64.tar.gz"
    if [ ! -e $GO_TAR ]; then
        echo -e "${GREEN}INFO :: Downloading GO tar file...${NC}"
        wget https://dl.google.com/go/go1.20.6.linux-amd64.tar.gz
    fi
    
    echo -e "${GREEN}INFO :: GO tar file already exists...${NC}"
    sleep 2s

    if [ $? != 0 ]; then
      echo
      echo  -e "${RED}## ERROR :: Go package download encoutered issues${NC}"
      echo  -e "${RED}## ERROR :: re-trying download once more...${NC}"
      wget https://dl.google.com/go/go1.20.6.linux-amd64.tar.gz
      sleep 1s
      if [ $? != 0 ]; then
        echo -e "${RED}## WGET of Go package failed... exiting${NC}"
        FUNC_EXIT_ERROR
      fi
    else
      echo -e "${GREEN}INFO :: Successfully downloaded${NC}"
    fi



    # Extract GO install binaries 
    sudo tar -xvf go1.20.6.linux-amd64.tar.gz



    # Set GO Package PATH values
    sudo mv go /usr/local
    export GOROOT=/usr/local/go
    export GOPATH=$HOME/go
    export PATH=$GOPATH/bin:$GOROOT/bin:$PATH

    GO_VER=$(go version)
    go version; GO_EC=$?
    case $GO_EC in
        0) echo -e "${GREEN}## Command exited with NO error...${NC}"
            echo $GO_VER
            echo
            echo -e "${GREEN}## Install proceeding as normal...${NC}"
            ;;
        1) echo -e "${RED}## Command exited with ERROR - exiting...${NC}"
            echo -e "${RED}## Check GO Version manually...${NC}"
            sleep 2s
            FUNC_EXIT_ERROR
            #exit 1
            ;;
        *) echo -e "${RED}## Command exited with OTHER ERROR...${NC}"
            echo -e "${RED}## 'go version' returned : $GO_EC ${NC}"
            FUNC_EXIT_ERROR
            #exit 1
            ;;
    esac



    # Get Node Version Manager (NVM) Package & execute 
    cd ~/
    curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
    if [ $? != 0 ]; then
      echo
      echo  -e "${RED}## ERROR :: NVM package download / install encoutered issues${NC}"
      sleep 2s
      FUNC_EXIT_ERROR
    else
      echo -e "${GREEN}INFO :: Successfully downloaded & executed NVM install script${NC}"
      sleep 2s
    fi



    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## Install: Clone GoPlugin V2 repo...${NC}"
     
    git clone https://github.com/GoPlugin/pluginV2.git

    echo -e "${GREEN}## Install: switch to GoPlugin V2 folder...${NC}"
    cd $PLI_DEPLOY_PATH


    echo -e "${GREEN}## Install: remove default API credentials file...${NC}"
    rm -f apicredentials.txt
    sleep 2s


    ###########################  Add Mainnet details  ##########################

    #V2_CONF_FILE="$PLI_DEPLOY_PATH/config.toml"

    sed -i.bak "s/HTTPSPort = 0/HTTPSPort = $PLI_HTTPS_PORT/g" $PLI_DEPLOY_PATH/$BASH_FILE3


    if [ "$_OPTION" == "mainnet" ]; then
        echo -e "${GREEN} ### Configuring node for ${BYELLOW}$_OPTION${GREEN}..  ###${NC}"

        VARVAL_CHAIN_NAME=$mainnet_name
        VARVAL_CHAIN_ID=$mainnet_ChainID
        VARVAL_CONTRACT_ADDR=$mainnet_ContractAddress
        VARVAL_WSS=$mainnet_wsUrl
        VARVAL_RPC=$mainnet_httpUrl

    elif [ "$_OPTION" == "apothem" ]; then
        echo -e "${GREEN} ### Configuring node for ${BYELLOW}$_OPTION${GREEN}..  ###${NC}"

        VARVAL_CHAIN_NAME=$testnet_name
        VARVAL_CHAIN_ID=$testnet_ChainID
        VARVAL_CONTRACT_ADDR=$testnet_ContractAddress
        VARVAL_WSS=$testnet_wsUrl
        VARVAL_RPC=$testnet_httpUrl
                    
    fi


    # get current Chains
    #EVM_CHAIN_ID=$(sudo -u postgres -i psql -d plugin_mainnet_db -AXqtc "select id from evm_chains;")
    #echo $EVM_CHAIN_ID
    ### returns 50
#
    ## delete existing evm chain id
    #sudo -u postgres -i psql -d plugin_mainnet_db -c "DELETE from evm_chains WHERE id = '$EVM_CHAIN_ID';"

    sed  -i 's|^ChainID.*|ChainID = '\'$VARVAL_CHAIN_ID\''|g' $PLI_DEPLOY_PATH/$BASH_FILE3
    cat $PLI_DEPLOY_PATH/$BASH_FILE3 | grep ChainID

    sed  -i 's|^LinkContractAddress.*|LinkContractAddress = '\"$VARVAL_CONTRACT_ADDR\"'|g' $PLI_DEPLOY_PATH/$BASH_FILE3
    cat $PLI_DEPLOY_PATH/$BASH_FILE3 | grep LinkContractAddress

    sed  -i 's|^name.*|name = '\"$VARVAL_CHAIN_NAME\"'|g' $PLI_DEPLOY_PATH/$BASH_FILE3
    cat $PLI_DEPLOY_PATH/$BASH_FILE3 | grep name

    sed  -i 's|^wsUrl.*|wsUrl = '\"$VARVAL_WSS\"'|g' $PLI_DEPLOY_PATH/$BASH_FILE3
    cat $PLI_DEPLOY_PATH/$BASH_FILE3 | grep wsUrl

    sed  -i 's|^httpUrl.*|httpUrl = '\'$VARVAL_RPC\''|g' $PLI_DEPLOY_PATH/$BASH_FILE3
    cat $PLI_DEPLOY_PATH/$BASH_FILE3 | grep httpUrl


    ###########################################################################



    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## Install: GoPlugin V2 NVM...${NC}"

    echo -e "${GREEN}## Source NVM environmentals shell script...${NC}"
    source ~/.nvm/nvm.sh
    sleep 2s

    # Install Node Manager Package version & enable

    echo -e "${GREEN}## NVM install & use...${NC}"
    nvm install 16.14.0
    nvm use 16.14.0
    node --version
    


    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## Install: GoPlugin V2 dependancies...${NC}"

    npm install -g pnpm 
    if [ $? != 0 ]; then
      echo
      echo  -e "${RED}## ERROR :: PNPM dependancies install encoutered issues${NC}"
      sleep 2s
      FUNC_EXIT_ERROR
    else
      echo -e "${GREEN}INFO :: Successfully downloaded & installed PNPM ${NC}"
      sleep 2s
    fi

    npm install -g  wscat
    if [ $? != 0 ]; then
      echo
      echo  -e "${RED}## ERROR :: WSCAT dependancies install encoutered issues${NC}"
      sleep 2s
      FUNC_EXIT_ERROR
    else
      echo -e "${GREEN}INFO :: Successfully downloaded & installed WSCAT ${NC}"
      sleep 2s
    fi



    # Build packages..

    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## Install: install build complier files...${NC}"
     
    sudo apt install -y build-essential



    # Make Install

    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## Install: Complie dependancy install files...${NC}"
     
    make install
    if [ $? != 0 ]; then
      echo
      echo  -e "${RED}## ERROR :: MAKE install encoutered issues${NC}"
      sleep 2s
      FUNC_EXIT_ERROR
    else
      echo -e "${GREEN}INFO :: Successfully complied dependancy install files${NC}"
      sleep 2s
    fi
    
    touch {$FILE_KEYSTORE,$FILE_API}
    chmod 666 {$FILE_KEYSTORE,$FILE_API}

    echo $API_EMAIL > $FILE_API
    echo $API_PASS >> $FILE_API
 
    echo 
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## Install: UPDATE file $BASH_FILE1 with new DB password value...${NC}"

    sed -i.bak "/^URL*/c\URL = 'postgresql://postgres:$DB_PWD_NEW@127.0.0.1:5432/$DB_NAME?sslmode=disable'" $BASH_FILE1
    sleep 1s

    echo 
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## Install: UPDATE file $BASH_FILE1 with new KEYSTORE password value...${NC}"


    sed -i "/^Keystore*/c\Keystore = '$PASS_KEYSTORE'" $BASH_FILE1
    
    echo 
    echo -e "${GREEN}## Install: Update file $BASH_FILE3 with TLS values...${NC}"

    sed -i.bak "s/HTTPSPort = 0/HTTPSPort = $PLI_HTTPS_PORT/g" $BASH_FILE3
    sed -i "/^HTTPSPort*/a\CertPath = '$TLS_CERT_PATH/server.crt'\nKeyPath = '$TLS_CERT_PATH/server.key'" $BASH_FILE3

    echo 
    echo -e "${GREEN}## Install: Create TLS CA / Certificate & files / folders...${NC}"

    mkdir $TLS_CERT_PATH && cd $TLS_CERT_PATH
    openssl req -x509 -out server.crt -keyout server.key -newkey rsa:4096 \
-sha256 -days 3650 -nodes -extensions EXT -config \
<(echo "[dn]"; echo CN=localhost; echo "[req]"; echo distinguished_name=dn; echo "[EXT]"; echo subjectAltName=DNS:localhost; echo keyUsage=digitalSignature; echo \
extendedKeyUsage=serverAuth) -subj "/CN=localhost"
    sleep 1s



    # Update user profile with GO path values
    
    isInFile=$(cat ~/.profile | grep -c "GOROOT*")
    if [ $isInFile -eq 0 ]; then
        echo "export GOROOT=/usr/local/go" >> ~/.profile
        echo "export GOPATH=$HOME/go" >> ~/.profile
        echo "PATH=$GOPATH/bin:$GOROOT/bin:$PATH" >> ~/.profile
        echo "SECURE_COOKIES=false" >> ~/.profile

        echo -e "${GREEN}## Success: '.profile' updated with GO PATH values...${NC}"
    else
        echo -e "${GREEN}## Skipping: '.profile' contains GO PATH values...${NC}"
    fi

    source ~/.profile



    echo -e "${GREEN}## Install: Create PM2 file $BASH_FILE2 & set auto start on reboot...${NC}"

    cd /$PLI_DEPLOY_PATH
    cat <<EOF > $BASH_FILE2
#!/bin/bash
echo "<<<<<<<<<--------------------------------STARTING PLUGIN 2.0 VALIDATOR NODE----------------------------------->>>>>>>>>"
plugin --admin-credentials-file apicredentials.txt -c config.toml -s secrets.toml node start
echo "<<<<<<<<<------------------PLUGIN 2.0 VALIDATOR NODE is running .. use "pm2 status" to check details--------------------->>>>>>>>>"
EOF
    chmod +x $BASH_FILE2

    npm install pm2 -g

    pm2 startup systemd
    sudo env PATH=$PATH:/home/$USER_ID/.nvm/versions/node/v16.14.0/bin /home/$USER_ID/.nvm/versions/node/v16.14.0/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER_ID --hp /home/$USER_ID
    pm2 save




    echo -e "${GREEN}## Install: Create Expect script...${NC}"
    sleep 1s


    cat <<EOF > expect.sh
#!/usr/bin/expect -f
log_user 0
set timeout 15

set API_EMAIL [lindex $argv 0]
set API_PASS [lindex $argv 1]


spawn ./NodeStartPM2.sh

expect "*Enter API Email?" { send -- "$API_EMAIL\r" }
expect "*Enter API Password?" { send -- "$API_PASS\r" }
expect eof
exit 0
EOF
    chmod +x expect.sh
    

 
    echo 
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## Install: RUN Expect script...${NC}"
    echo
    sleep 1s

    ./expect.sh $API_EMAIL $API_PASS 

    sleep 2s

    echo -e "${GREEN}## Install: PM2 RUN $BASH_FILE2 ...${NC}"
    pm2 start $BASH_FILE2
    pm2 save
    
    pm2 list 
    sleep 2s
    pm2 list
    sleep 5s
    #clear
    echo
    echo
    echo
    echo
    echo
    echo
    echo
    echo
    echo
    echo
    echo
    echo
    echo
    echo
    echo
    echo
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}#######   Preparing final details - please wait..  #########${NC}"
    echo
    echo -e "${GREEN}#########################################################################${NC}"

    sleep 10s
    FUNC_LOGROTATE;
    #clear
    echo
    echo
    echo
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## INFO :: Install process completed for ${BYELLOW}$_OPTION${GREEN} node.  exiting...${NC}"
    echo
    echo -e "${GREEN}## INFO :: ${BYELLOW}$_OPTION${GREEN} Contract Address = ${BYELLOW}$VARVAL_CONTRACT_ADDR ${NC}"
    echo
    FUNC_NODE_ADDR;
    echo -e "${GREEN}## INFO :: Your Plugin ${BYELLOW}$_OPTION${GREEN} node regular address is:${NC} ${BYELLOW}$node_key_primary ${NC}"
    
    echo
    #echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${RED}##  IMPORTANT INFORMATION - PLEASE RECORD TO YOUR PASSWORD SAFE${NC}"
    echo
    echo -e "${GREEN}--------------------------------------------------------------------------${NC}"
    echo
    echo -e "${RED}##  KEY STORE SECRET:        $PASS_KEYSTORE${NC}"
    echo -e "${RED}##  POSTGRES DB PASSWORD:    $DB_PWD_NEW${NC}"
    echo
    echo -e "${RED}##  API USERNAME:    $API_EMAIL${NC}"
    echo -e "${RED}##  API PASSWORD:    $API_PASS${NC}"
    echo
    #echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ACTION: paste the following to update your session with updated env variables..${NC}"
    echo
    echo -e "${GREEN}##          source ~/.profile${NC}"
    echo

    FUNC_NODE_GUI_IPADDR;
    sleep 3s
    FUNC_EXPORT_NODE_KEYS;
    FUNC_EXIT;
    }




FUNC_EXPORT_NODE_KEYS(){


source ~/"plinode_$(hostname -f)".vars
echo 
echo -e "${GREEN}#########################################################################${NC}"
echo -e "${GREEN}## INFO :: export ${BYELLOW}$_OPTION${GREEN} node keys ${NC}"
echo 
echo -e "${RED}######    IMPORTANT FILE - NODE ADDRESS EXPORT FOR WALLET ACCESS  -   PLEASE SECURE APPROPRIATELY   #####${NC}"
echo 
echo -e "${GREEN}## INFO :: exporting keys to file: ~/"plinode_$(hostname -f)_keys_${FDATE}".json${NC}"
echo
echo -e "${GREEN}#########################################################################${NC}"
echo
echo
echo

if [ ! -e $PLI_DEPLOY_PATH/pass ]; then
    #echo $PASS_KEYSTORE > $PLI_DEPLOY_PATH/pass
    echo $PASS_KEYSTORE > /tmp/pass
    #chmod 400 $PLI_DEPLOY_PATH/pass
    chmod 400 /tmp/pass
fi

FUNC_NODE_ADDR;

plugin keys eth export $node_key_primary --newpassword  /tmp/pass --output ~/"plinode_$(hostname -f)_keys_${FDATE}".json > /dev/null 2>&1

#echo -e "${GREEN}   export ${BYELLOW}$_OPTION${GREEN} node keys - securing file permissions${NC}"
chmod 400 ~/"plinode_$(hostname -f)_keys_${FDATE}".json

#chmod 600 $PLI_DEPLOY_PATH/pass
#rm -f $PLI_DEPLOY_PATH/pass
chmod 600 /tmp/pass
rm -f /tmp/pass
sleep 4s
}








FUNC_LOGROTATE(){
    # add the logrotate conf file
    # check logrotate status = cat /var/lib/logrotate/status

    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## ADDING LOGROTATE CONF FILE...${NC}"
    sleep 2s

    USER_ID=$(getent passwd $EUID | cut -d: -f1)

    if [ "$USER_ID" == "root" ]; then
        cat <<EOF > /tmp/tmpplugin-logs
/$USER_ID/.pm2/logs/*.log
/$USER_ID/.plugin/*.log
        {
            su $USER_ID $USER_ID
            rotate 10
            copytruncate
            daily
            missingok
            notifempty
            compress
            delaycompress
            sharedscripts
            postrotate
                    invoke-rc.d rsyslog rotate >/dev/null 2>&1 || true
            endscript
        }    
EOF
    else
        cat <<EOF > /tmp/tmpplugin-logs
/home/$USER_ID/.pm2/logs/*.log
/home/$USER_ID/.plugin/*.log
        {
            su $USER_ID $USER_ID
            rotate 10
            copytruncate
            daily
            missingok
            notifempty
            compress
            delaycompress
            sharedscripts
            postrotate
                    invoke-rc.d rsyslog rotate >/dev/null 2>&1 || true
            endscript
        }    
EOF
    fi

    sudo sh -c 'cat /tmp/tmpplugin-logs > /etc/logrotate.d/plugin-logs'

}


FUNC_NODE_ADDR(){
    source ~/"plinode_$(hostname -f)".vars
    cd ~/$PLI_DEPLOY_DIR
    plugin admin login -f $FILE_API > /dev/null 2>&1
    node_keys_arr=()
    IFS=$'\n' read -r -d '' -a node_keys_arr < <( plugin keys eth list | grep Address && printf '\0' )
    node_key_primary=$(echo ${node_keys_arr[0]} | sed s/Address:[[:space:]]/''/)
    
    #echo -e "${GREEN}## INFO :: Your Plugin ${BYELLOW}$_OPTION${GREEN} node regular address is:${NC} ${BYELLOW}$node_key_primary ${NC}"
    #echo
    #echo -e "${GREEN}#########################################################################${NC}"
}


FUNC_NODE_GUI_IPADDR(){
    GUI_IP=$(curl -s ipinfo.io/ip)
    echo
    echo -e "${GREEN}## INFO :: Your Plugin ${BYELLOW}$_OPTION${GREEN} node GUI IP address is as follows:${NC}"
    echo
    echo -e "            ${RED}https://$GUI_IP:6689${NC}"
    echo
    echo -e "${GREEN}#########################################################################${NC}"
}


FUNC_EXIT(){
    # remove the sudo timeout for USER_ID
    sudo sh -c 'rm -f /etc/sudoers.d/plinode_deploy'
    bash ~/.profile
    sudo -u $USER_ID sh -c 'bash ~/.profile'
	exit 0
	}


FUNC_EXIT_ERROR(){
	exit 1
	}
  

#clear
case "$1" in
        mainnet)
                _OPTION="mainnet"
                FUNC_NODE_DEPLOY
                ;;
        apothem)
                _OPTION="apothem"
                FUNC_NODE_DEPLOY
                ;;
        keys)
                FUNC_EXPORT_NODE_KEYS
                ;;
        logrotate)
                FUNC_LOGROTATE
                ;;
        address)
                FUNC_NODE_ADDR
                ;;
        node-gui)
                FUNC_NODE_GUI_IPADDR
                ;;
        *)
                
                echo 
                echo 
                echo "Usage: $0 {function}"
                echo 
                echo "    example: " $0 mainnet""
                echo 
                echo 
                echo "where {function} is one of the following;"
                echo 
                echo "      mainnet       ==  deploys the full Mainnet node & exports the node keys"
                echo 
                echo "      apothem       ==  deploys the full Apothem node & exports the node keys"
                echo
                echo "      keys          ==  extracts the node keys from DB and exports to json file for import to MetaMask"
                echo
                echo "      logrotate     ==  implements the logrotate conf file "
                echo
                echo "      address       ==  displays the local nodes address (after full node deploy) - required for the 'Fulfillment Request' remix step"
                echo
                echo "      node-gui      ==  displays the local nodes full GUI URL to copy and paste to browser"
                echo
esac
