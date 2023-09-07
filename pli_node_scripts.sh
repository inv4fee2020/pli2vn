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
RED='\033[0;31m'
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

    echo -e "${GREEN}#########################################################################"
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

    echo -e "${GREEN}#########################################################################"
    echo -e "${GREEN}## CONFIRM SCRIPTS VARIABLES FILE HAS BEEN UPDATED...${NC}"

    # Ask the user acc for login details (comment out to disable)
    CHECK_PASSWD=false
        while true; do
            read -t7 -r -p "please confirm that you have updated the vars file with your values ? (Y/n) " _input
            if [ $? -gt 128 ]; then
                #clear
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
    #echo -e "${GREEN}     YOUR NODE VARS FILE WILL BE UPDATED WITH THE GENERATED CREDENTIALS${NC}"
    sleep 2s

    #_AUTOGEN_KEYSTORE="'$(cat /dev/urandom | tr -dc 'a-zA-Z0-9%:+*!;.?=' | head -c32)'"
    _AUTOGEN_KEYSTORE="'$(./gen_passwd.sh -keys)'"
    sed -i 's/^PASS_KEYSTORE.*/PASS_KEYSTORE='"$_AUTOGEN_KEYSTORE"'/g' ~/"plinode_$(hostname -f)".vars
    PASS_KEYSTORE=$_AUTOGEN_KEYSTORE
    fi


    if ([ -z "$DB_PWD_NEW" ] || [ "$DB_PWD_NEW" == "$SAMPLE_DB_PWD" ]); then
    echo 
    echo -e "${GREEN}     VARIABLE 'DB_PWD_NEW' NOT UPDATED MANUALLY - AUTO GENERATING VALUE NOW"
    #echo -e "${GREEN}     YOUR NODE VARS FILE WILL BE UPDATED WITH THE GENERATED CREDENTIALS${NC}"
    sleep 2s

    #_AUTOGEN_DB_PWD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w20 | head -n1)
    _AUTOGEN_DB_PWD="$(./gen_passwd.sh -db)"
    sed -i 's/^DB_PWD_NEW.*/DB_PWD_NEW=\"'"${_AUTOGEN_DB_PWD}"'\"/g' ~/"plinode_$(hostname -f)".vars
    DB_PWD_NEW=$_AUTOGEN_DB_PWD
    fi


    if ([ -z "$API_EMAIL" ] || [ "$API_EMAIL" == "$SAMPLE_API_EMAIL" ]); then
    
    echo 
    echo -e "${GREEN}     VARIABLE 'API_EMAIL' NOT UPDATED MANUALLY - AUTO GENERATING VALUE NOW"
    #echo -e "${GREEN}     YOUR NODE VARS FILE WILL BE UPDATED WITH THE GENERATED CREDENTIALS${NC}"
    sleep 2s

    _AUTOGEN_API_USER=$(tr -cd A-Za-z < /dev/urandom | fold -w10 | head -n1)
    API_EMAIL_NEW="$_AUTOGEN_API_USER@plinode.local"
    sed -i 's/^API_EMAIL.*/API_EMAIL=\"'"${API_EMAIL_NEW}"'\"/g' ~/"plinode_$(hostname -f)".vars
    API_EMAIL=$API_EMAIL_NEW
    fi



    if ([ -z "$API_PASS" ] || [ "$API_PASS" == "$SAMPLE_API_PASS" ]); then

    echo 
    echo -e "${GREEN}     VARIABLE 'API_PASS' NOT UPDATED MANUALLY - AUTO GENERATING VALUE NOW"
    #echo -e "${GREEN}     YOUR NODE VARS FILE WILL BE UPDATED WITH THE GENERATED CREDENTIALS${NC}"
    echo
    sleep 2s

    #_AUTOGEN_API_PWD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w18 | head -n1)
    _AUTOGEN_API_PWD="'$(./gen_passwd.sh -api)'"
    sed -i 's/^API_PASS.*/API_PASS='"${_AUTOGEN_API_PWD}"'/g' ~/"plinode_$(hostname -f)".vars
    API_PASS=$_AUTOGEN_DB_PWD
    fi

    # Update the system memory with the newly updated variables
    source ~/"plinode_$(hostname -f)".vars

}



FUNC_NODE_DEPLOY(){
    
    echo -e "${GREEN}#########################################################################"
    echo -e "${GREEN}#########################################################################"
    echo -e "${GREEN}"
    echo -e "${GREEN}             GoPlugin 2.0 Validator Node - Install"
    echo -e "${GREEN}"
    echo -e "${GREEN}#########################################################################"
    echo -e "${GREEN}#########################################################################${NC}"
    
    # Set working directory to user home folder
    #cd ~/


    # loads variables 
    FUNC_VARS;

    # call base_sys_setup script to perform basic system updates etc.
    #source ~/pli2vn/base_sys_setup.sh -D
    bash base_sys_setup.sh -D

    echo
    echo -e "${GREEN}#########################################################################"
    echo -e "${GREEN}## Install: check credentials are updated against default sample values...${NC}"
    FUNC_PASSWD_CHECKS;

    # installs default packages listed in vars file
    FUNC_PKG_CHECK;

    echo
    echo -e "${GREEN}#########################################################################"
    echo -e "${GREEN}## Install: GO & NVM Packages...${NC}"
     
    
    #if [ ! -d "/$PLI_BASE_DIR" ]; then
    #    sudo mkdir "/$PLI_BASE_DIR"
    #    #USER_ID=$(getent passwd $EUID | cut -d: -f1)
    #    sudo chown $USER_ID\:$USER_ID -R "/$PLI_BASE_DIR"
    #fi

    #cd /$PLI_BASE_DIR
    #git clone https://github.com/GoPlugin/plugin-deployment.git && cd plugin-deployment
    #rm -f {apicredentials.txt,password.txt}
    #sleep 2s





    # SQL Install

    echo
    echo -e "${GREEN}#########################################################################"
    echo -e "${GREEN}## Install: POSTGRES DB ${NC}"

    cd ~/
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/pgdg.asc &>/dev/null

    sudo apt install -y postgresql postgresql-client
    sudo systemctl start postgresql.service
    #sudo -i -u postgres psql

# sudo -u postgres -i psql -d $DB_NAME -t -c"select json from keys where id=1;")

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
    wget https://dl.google.com/go/go1.20.6.linux-amd64.tar.gz
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
    #go version

    GO_VER=$(go version)
    go version; GO_EC=$?
    case $GO_EC in
        0) echo -e "${GREEN}## Command exited with NO error...${NC}"
            echo $GO_VER
            echo
            echo -e "${GREEN}## Install proceeding as normal...${NC}"
            ;;
        1) echo -e "${RED}## Command exited with ERROR - exiting...${NC}"
            #source ~/.profile;
            #sudo sh -c 'echo "export PATH=$PATH:/usr/local/go/bin" >> /etc/profile'
            #echo "cat "export PATH=$PATH:/usr/local/go/bin" >> ~/.profile"
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
    echo -e "${GREEN}#########################################################################"
    echo -e "${GREEN}## Install: Clone GoPlugin V2 repo...${NC}"
     
    git clone https://github.com/GoPlugin/pluginV2.git

    echo -e "${GREEN}## Install: switch to GoPlugin V2 folder...${NC}"
    cd $PLI_DEPLOY_PATH


    echo -e "${GREEN}## Install: remove default API credentials file...${NC}"
    rm -f apicredentials.txt
    sleep 2s



    echo
    echo -e "${GREEN}#########################################################################"
    echo -e "${GREEN}## Install: GoPlugin V2 NVM...${NC}"

    #source ~/.bashrc
    #cd $PLI_DEPLOY_PATH
    #export NVM_DIR=$HOME/.nvm

    echo -e "${GREEN}## Source NVM environmentals shell script...${NC}"
    source ~/.nvm/nvm.sh
    sleep 2s

    # Install Node Manager Package version & enable

    echo -e "${GREEN}## NVM install & use...${NC}"
    nvm install 16.14.0
    nvm use 16.14.0
    node --version
    


    echo
    echo -e "${GREEN}#########################################################################"
    echo -e "${GREEN}## Install: GoPlugin V2 dependancies...${NC}"

    #export NVM_DIR="$HOME/.nvm"
    #source ~/.bashrc
    npm install -g pnpm
    if [ $? != 0 ]; then
      echo
      echo  -e "${RED}## ERROR :: PNPM dependancies install encoutered issues${NC}"
      #echo  -e "${RED}## ERROR :: re-trying download once more...${NC}"
      #wget https://dl.google.com/go/go1.20.6.linux-amd64.tar.gz
      sleep 2s
      FUNC_EXIT_ERROR
    else
      echo -e "${GREEN}INFO :: Successfully downloaded & installed dependancies${NC}"
      sleep 2s
    fi



    # Build packages..

    echo
    echo -e "${GREEN}#########################################################################"
    echo -e "${GREEN}## Install: install build complier files...${NC}"
     
    sudo apt install -y build-essential



    # Make Install

    echo
    echo -e "${GREEN}#########################################################################"
    echo -e "${GREEN}## Install: Complie dependancy install files...${NC}"
     
    make install
    if [ $? != 0 ]; then
      echo
      echo  -e "${RED}## ERROR :: MAKE install encoutered issues${NC}"
      #echo  -e "${RED}## ERROR :: re-trying download once more...${NC}"
      #wget https://dl.google.com/go/go1.20.6.linux-amd64.tar.gz
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
    #echo $PASS_KEYSTORE > $FILE_KEYSTORE

    #chmod 600 {$FILE_KEYSTORE,$FILE_API}

    # Remove the file if necessary; sudo rm -f {.env.apicred,.env.password}
 
    echo 
    echo -e "${GREEN}#########################################################################"
    echo -e "${GREEN}## Install: UPDATE file $BASH_FILE1 with new DB password value...${NC}"

    #sed -i.bak "s/$DB_PWD_FIND/'$DB_PWD_NEW'/g" $BASH_FILE1
    sed -i.bak "/^URL*/c\URL = 'postgresql://postgres:$DB_PWD_NEW@127.0.0.1:5432/$DB_NAME?sslmode=disable'" $BASH_FILE1
    #cat $BASH_FILE1 | grep 'postgres PASSWORD'
    sleep 1s

    echo 
    echo -e "${GREEN}#########################################################################"
    echo -e "${GREEN}## Install: UPDATE file $BASH_FILE1 with new KEYSTORE password value...${NC}"


    sed -i "/^Keystore*/c\Keystore = '$PASS_KEYSTORE'" $BASH_FILE1
    #sleep 1s

    

     
    echo 
    echo -e "${GREEN}## Install: Update file $BASH_FILE3 with TLS values...${NC}"

    sed -i.bak "s/HTTPSPort = 0/HTTPSPort = $PLI_HTTPS_PORT/g" $BASH_FILE3
    sed -i "/^HTTPSPort*/a\CertPath = '$TLS_CERT_PATH/server.crt'\nKeyPath = '$TLS_CERT_PATH/server.key'" $BASH_FILE3
    #sed "s/^ForceRedirect*/ForceRedirect = true/g" $BASH_FILE3

    #sleep 1s


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



    echo -e "${GREEN}## Install: Start PM2 $BASH_FILE2 & set auto start on reboot...${NC}"

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

    sleep2s

    pm2 start $BASH_FILE2
    pm2 save all
    pm2 stop all
    #sleep 1s
    #pm2 list 
    
    #sleep 2s
    #pm2 list
    # NON-INTERACTIVE: Proceed with next stage of setup.
    #FUNC_EXPORT_NODE_KEYS;
    #FUNC_INITIATOR;

    echo -e "${GREEN}## MANUAL ACTION: Start node processes & enter credentials (one time only)...${NC}"
    echo
    echo -e "${GREEN}## paste in the following command and enter the API credentials when prompted..${NC}"
    echo -e "${GREEN}##  plugin --admin-credentials-file $PLI_DEPLOY_PATH/apicredentials.txt -c $PLI_DEPLOY_PATH/config.toml -s $PLI_DEPLOY_PATH/secrets.toml node start  ${NC}"
    
    echo
    echo
    echo
    echo -e "${GREEN}## Your API Credentials ${NC}"
    echo
    cat $PLI_DEPLOY_PATH/apicredentials.txt
    source ~/.profile
    }




FUNC_EXPORT_NODE_KEYS(){


source ~/"plinode_$(hostname -f)".vars
echo 
echo -e "${GREEN}#########################################################################${NC}"
echo -e "${GREEN}   export node keys {NC}"

#sudo usermod -aG postgres $(getent passwd $EUID | cut -d: -f1)

#echo 
#echo -e "${GREEN}#########################################################################${NC}"
echo 
echo -e   "${RED}######    IMPORTANT FILE - NODE ADDRESS EXPORT FOR WALLET ACCESS    #####${NC}"
echo -e   "${RED}######    IMPORTANT FILE - PLEASE SECURE APPROPRIATELY               #####${NC}"
echo 
echo -e "${GREEN}   export node keys - exporting keys to file: ~/"plinode_$(hostname -f)_keys_${FDATE}".json${NC}"
FUNC_NODE_ADDR

if [ ! -e $PLI_DEPLOY_PATH/pass ]; then
    echo $PASS_KEYSTORE > $PLI_DEPLOY_PATH/pass
    chmod 400 $PLI_DEPLOY_PATH/pass
fi

plugin keys eth export $node_key_primary --newpassword  $PLI_DEPLOY_PATH/pass --output ~/"plinode_$(hostname -f)_keys_${FDATE}".json

#echo $(sudo -u postgres -i psql -d '$DB_NAME' -c "select json from keys where id=1;")  > ~/"plinode_$(hostname -f)_keys_${FDATE}".json
 
echo -e "${GREEN}   export node keys - securing file permissions${NC}"

chmod 400 ~/"plinode_$(hostname -f)_keys_${FDATE}".json
sleep 4s
}








FUNC_LOGROTATE(){
    # add the logrotate conf file
    # check logrotate status = cat /var/lib/logrotate/status

    echo -e "${GREEN}#########################################################################"
    echo -e "${GREEN}## ADDING LOGROTATE CONF FILE...${NC}"
    sleep 2s

    USER_ID=$(getent passwd $EUID | cut -d: -f1)

    if [ "$USER_ID" == "root" ]; then
        cat <<EOF > /tmp/tmpplugin-logs
/$USER_ID/.pm2/logs/*.log
/$USER_ID/.plugin/*.jsonl
/$USER_ID/.cache/*.logf
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
/home/$USER_ID/.plugin/*.jsonl
/home/$USER_ID/.cache/*.logf
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
    plugin admin login -f $FILE_API
    node_keys_arr=()
    IFS=$'\n' read -r -d '' -a node_keys_arr < <( plugin keys eth list | grep Address && printf '\0' )
    node_key_primary=$(echo ${node_keys_arr[0]} | sed s/Address:[[:space:]]/''/)
    echo
    echo -e "${GREEN}Your Plugin node regular address is:${NC} ${RED}$node_key_primary ${NC}"
    echo
    echo -e "${GREEN}#########################################################################${NC}"
}


FUNC_NODE_GUI_IPADDR(){
    GUI_IP=$(curl -s ipinfo.io/ip)
    echo
    echo -e "${GREEN}Your Plugin node GUI IP address is as follows:${NC}"
    echo
    echo -e "            ${RED}https://$GUI_IP:6689${NC}"
    echo
    echo -e "${GREEN}#########################################################################${NC}"
}


FUNC_EXIT(){
    # remove the sudo timeout for USER_ID
    sudo sh -c 'rm -f /etc/sudoers.d/plinode_deploy'
    source ~/.profile
	exit 0
	}


FUNC_EXIT_ERROR(){
	exit 1
	}
  

#clear
case "$1" in
        full)
                #_OPTION="fullnode"
                FUNC_NODE_DEPLOY
                #FUNC_VALUE_CHECK
                ;;
        #initiator)
        #        _OPTION="initiator"
        #        FUNC_INITIATOR
        #        ;;
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
                echo "    example: " $0 full""
                echo 
                echo 
                echo "where {function} is one of the following;"
                echo 
                echo "      full          ==  deploys the full node incl. external initiator & exports the node keys"
                #echo 
                #echo "      initiator     ==  creates / rebuilds the external initiator only"
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