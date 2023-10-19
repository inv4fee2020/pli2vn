# pli2vn
Modular scripts for @GoPlugin 2.0 Validator Node setup & maintenance.

> **NOTE: All values used in this code are for test purposes only & deployed to a test environment that is regularly deleted.**
> **NOTE: Please ensure that you update with your own values as necessary.**

---
---
|**NOTE : !! Be sure to perform a [Full Backup](node_backup_restore.md) of your system once it has been approved !!**|
|---|
---



...
...


---

> When connecting to your nodes web GUI you must use *_'https://your_node_ip:6689'_* instead due to the configuration applied by the main script


---
---
## VARIABLES file

A sample vars file is included 'sample.vars'. This file will be copied to your user $HOME folder as part of the main script and the permissions to the file updated to restrict access to the owner of the $HOME folder.

The scripts check that the local node variables file exists.

By using a dedicated variables file, any updates to the main script should not involve any changes to the node specific settings.




---
---
## pli_node_scripts.sh (main script)

This script performs file manipulations & executes the various plugin bash scripts in order 
to successfully deploy the node. 

The scripts has a number of functions, one of which must be passed to run the scripts

>     mainnet
>     apothem
>     keys
>     logrotate
>     address
>     node-gui

### Usage

        Usage: ./pli_node_scripts.sh {function}
            example:  ./pli_node_scripts.sh fullnode

        where {function} is one of the following;

              mainnet       ==  deploys the full Mainnet node & exports the node keys
              apothem       ==  deploys the full Apothem node & exports the node keys
              keys          ==  extracts the node keys from DB and exports to json file
              logrotate     ==  implements the logrotate conf file
              address       ==  displays the local nodes address (after fullnode deploy) - required for the 'Fulfillment Request' remix step
              node-gui      ==  displays the local nodes full GUI URL to copy and paste to browser

### Function: mainnet

As the name suggest, this executes all code to provision a full working node, on the _*Mainnet*_ chain, ready for the contract & jobs creation on remix.
This function calls all other function as part of deploying the full node.


### Function: apothem

As the name suggest, this executes all code to provision a full working node, on the _*Apothem*_ chain, ready for the contract & jobs creation on remix.
This function calls all other function as part of deploying the full node.


### Function: keys

This function exports the node address keys to allow you to access any funds that have been added to the node. This is important in scenarios where an operator wishes to rebuild a node or where they may have simply added too much funds to the node address.

The output json file (example below) is then imported to MM as per step 5 of ['Withdraw PLI from Plugin Node'](https://docs.goplugin.co/node-operators/withdraw-pli-from-plugin-node#step-5-now-choose-import-account-and-select-json-file-as-type.-pass-word-should-be-same-as-your-keys) of the offical docs.


### Function: logrotate

This function implements the necessary logrotate configuration to aid with the management of the nodes PM2 logs. By default the logging level is DEBUGGING and so if left un-checked, these logs will eventually consume all available disk space.

**NOTE: logs are set to rotate every 10 days.**

to check the state of the logrotate config, issue the following cmd;
        
        sudo cat /var/lib/logrotate/status | grep -i pm2 


### Function: Address

This function obtains the local nodes primary address. This is necessary for remix fulfillment & node submissions tasks.

        nmadmin@plitest:~/pli2vn$ ./pli_node_scripts.sh address

        Your Plugin node regular address is: 0x160C2b4b7ea040c58D733feec394774A915D0cb5

        #########################################################################


### Function: node-gui

This function is called at the end of the `fullnode` deployment process and displays the full URL for the local node so that it is available for the operator to copy and paste.  This aids in reducing any confusion on how the GUI should be accessed
.

        bhcadmin@plinode-test1:~/pli2vn$ ./pli_node_scripts.sh node-gui

        Your Plugin node GUI IP address is as follows:

                    https://192.0.0.101:6689

        #########################################################################



---
---


## reset_pli.sh

**WARNING:: USE WITH CAUTION**

As the name suggests this script does a full reset of you local Plugin installation.

User account deletion: The script does _NOT_ delete any other user or system accounts beyond that of _'postgres'_.

Basic function is to;

- stop & delete all PM2 processes
- stop all postgress services
- uninstall all postgres related components
- delete all postgres related system folders
- remove the postgres user & group
- delete all plugin installaton folders under the users $HOME folder
- removes path values from .bashrc & .profile

This script resets your VPS to a pre-deployment state, allowing you to re-install the node software without reseting the VPS system.


---
---


## base_sys_setup.sh

Updated to use modular functions allowing for individial functions to be run or 
You can reveiw the 'sample.vars' file for the full list of VARIABLES.

This script performs OS level commands as follows;

- Apply ubuntu updates
- Install misc. services & apps e.g. UFW, Curl, Git, locate 
- New Local Admin user & group (Choice of interactive user input OR hardcode in VARS definition)
- SSH keys for the above 
- Applies UFW firewall minimum configuration & starts/enables service
- Modifies UFW firewall logging to use only the ufw.log file
- Modify SSH service to use alternate service port, update UFW & restart SSH

_You can reveiw the 'sample.vars' file for the full list of VARIABLES._
### Usage

        Usage: ./base_sys_setup.sh {function}

        where {function} is one of the following;

              -D      ==  performs a normal base setup (excludes User acc & Securing SSH)"
                          -- this assumes you are installing under your current admin session (preferable not root)"

              -os     ==  perform OS updates & installs required packages (see sample.vars 'BASE_SYS_PACKAGES')
              
              -user   ==  Adds a new admin account (to install the plugin node under) & SSH keys

              -ports  ==  Adds required ports to UFW config (see sample.vars for 'PORT' variables )
                          -- Dynamically finds current active ssh port & adds to UFW ruleset

              -ufw    ==  Starts the UFW process, sets the logging to 'ufw.log' only & enables UFW service

              -S      ==  Secures the SSH service:
                          -- sets SSH to use port number 'your_defined_new_port'
                          -- sets authentication method to SSH keys ONLY (Password Auth is disabled)
                          -- adds port number 'your_defined_new_port' to UFW ruleset
                          -- restarts the SSH service to activate new settings (NOTE: Current session is unaffected)

*_NOTE: The script does read the local node specific vars file._*

---
---

## Refreshing your local repo

As the code is updated it will be necessary to update your local repo from time to time. To do this you have two options;

** ### USE CAUTION HERE : The following refresh commands will overwrite any existing local files that may contain specific configuration for your node**

1. Force git to update the local repo by overwriting the local changes, which in this case are the file permission changes. Copy and paste the following code;
        
        cd ~/pli2vn
        git fetch
        git reset --hard HEAD
        git merge '@{u}'
        chmod +x *.sh



   _source: https://www.freecodecamp.org/news/git-pull-force-how-to-overwrite-local-changes-with-git/_


2. Manually delete the folder and re-run the clone & permissions commands. Copy and paste the following code;
        
        cd $HOME
        rm -rf pli2vn
        git clone https://github.com/inv4fee2020/pli_node_conf.git
        cd pli2vn
        chmod +x *.sh
        


---
## Testing

The scripts have been developed on ubuntu 20.x linux distros.
