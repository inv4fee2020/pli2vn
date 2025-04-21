#!/bin/bash


# Get current user id and store as var
USER_ID=$(getent passwd $EUID | cut -d: -f1)


# Set Colour Vars
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

    echo -e "${RED}#########################################################################"
    echo -e "${RED}#########################################################################"
    echo -e "${RED}"
    echo -e "${RED}        !!  WARNING  !!${NC} Plugin Node Reset Script ${RED}!!  WARNING  !!${NC}"
    echo -e "${RED}"
    echo -e "${RED}#########################################################################"
    echo -e "${RED}#########################################################################${NC}"
    echo
    echo
    echo



    # Ask the user acc for login details (comment out to disable)
    CHECK_PASSWD=false
        while true; do
            read -t10 -r -p ":: DESTRUCTIVE :: Confirm that you wish to RESET your Plugin node installation ? (Y/n) " _input
            if [ $? -gt 128 ]; then
                #clear
                echo
                echo "timed out waiting for user response - quitting..."
                exit 0
            fi
            case $_input in
                [Yy][Ee][Ss]|[Yy]* )
                    break
                    ;;
                [Nn][Oo]|[Nn]* ) 
                    exit 0
                    ;;
                * ) echo "Please answer (y)es or (n)o.";;
            esac
        done


# Authenticate sudo perms before script execution to avoid timeouts or errors
sudo -l > /dev/null 2>&1

# Get local hostname and load the vars file
PLI_VARS_FILE="plinode_$(hostname -f).vars"
source ~/$PLI_VARS_FILE


echo -e "${GREEN} ~~ Performing fresh keys export ~~${NC}"
./pli_node_scripts.sh keys

##  Rough script to roll back installation for testing purposes...
## Use with caution !
#sudo su

# Stop & Delete all active PM2 processes
pm2 stop all && pm2 delete all

# Stop the POSTGRES service
sudo systemctl stop postgresql

# Delete folders for; Go install, plugin-deployment install, POSTGRES.
sudo rm -rf /usr/local/go
sudo rm -rf /$PLI_DEPLOY_PATH

sudo rm -rf /usr/lib/postgresql/ && sudo rm -rf /var/lib/postgresql/ && sudo rm -rf /var/log/postgresql/ && sudo rm -rf /etc/postgresql/ && sudo rm -rf /etc/postgresql-common/

# Remove the POSTGRES packages & clean up linked packages
sudo apt --purge remove postgresql* -y && sudo apt purge postgresql* -y 
sudo apt --purge remove postgresql -y postgresql-doc -y postgresql-common -y
sudo apt autoremove -y

# Clean up any remaining folders 
sudo rm -rf /usr/lib/postgresql/ && sudo rm -rf /var/lib/postgresql/ && sudo rm -rf /var/log/postgresql/ && sudo rm -rf /etc/postgresql/ && sudo rm -rf /etc/postgresql-common/

# Remove the POSTGRES install system account & group
#sudo userdel -r postgres && sudo groupdel postgres

if [ $(getent passwd postgres > /dev/null 2>&1) ]; then
    sudo userdel -r postgres
fi

if [ $(getent group postgres > /dev/null 2>&1) ]; then
    sudo groupdel postgres
fi


# Remove the group for local backups
if [ $(getent group nodebackup) > /dev/null 2>&1 ]; then
  sudo groupdel nodebackup
fi


# Remove all plugin, nodejs linked folders for current user & root
cd ~/ ; sudo sh -c "rm -rf .cache/ && rm -rf .nvm && rm -rf .npm && rm -rf .plugin && rm -rf Plugin && rm -rf .pm2 && rm -rf work && rm -rf go && rm -rf .yarn* && rm -rf .local"


if [ -e ~/.tmp_profile ]; then
    rm -f ~/.tmp_profile
fi

# Remove logrotate file
if [ -e /etc/logrotate.d/plugin-logs ]; then
    sudo sh -c 'rm -f /etc/logrotate.d/plugin-logs'
fi





sed -i.bak '/GOROOT=\/usr\/local\/go/d' ~/.profile
sed -i '/GOPATH=*/d' ~/.profile
sed -i '/PATH=\//d' ~/.profile
sed -i '/SECURE_COOKIES=false/d' ~/.profile

sed -i.bak '/export NVM_DIR="$HOME\/\.nvm/d' ~/.bashrc
sed -i '/[ -s "$NVM_DIR/nvm\.sh" ] \&\& \\\. "$NVM_DIR\/nvm\.sh"  # This loads nvm/d' ~/.bashrc
sed -i '/[ -s "$NVM_DIR/bash_completion" ] \&\& \\\. "$NVM_DIR\/bash_completion"  # This loads nvm bash_completion/d' ~/.bashrc

bash ~/.profile
sudo -u $USER_ID sh -c 'bash ~/.profile'


echo -e "${GREEN}#########################################################################"
    echo -e "${GREEN}## INFO: Reset process completed.  exiting...${NC}"
    echo
    echo
    echo  -e "${GREEN}## ACTION: paste the following to update your session with updated env variables..${NC}"
    echo
    echo -e "${GREEN}##          source ~/.profile${NC}"
