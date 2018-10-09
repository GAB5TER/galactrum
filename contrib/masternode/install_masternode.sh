#!/bin/bash

clear
cd ~

# Define color coding
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Define Galactrum variables
WALLET_VERSION="1.1.6"
RPC_PORT=6269
P2P_PORT=6270

# Determine Ubuntu release version
if [[ $(lsb_release -d) == *16.04* ]]; then
    UBUNTU_RELEASE=16
    WALLET_FOLDER="galactrum-1.1.6"
    WALLET_ZIP="galactrum-1.1.6-linux64.tar.gz"
    WALLET_LINK="https://github.com/galactrum/galactrum/releases/download/v${WALLET_VERSION}/${WALLET_ZIP}"
else
    echo -e "${RED}No wallet binaries have been generated for this Ubuntu release! Exiting...${NC}"
    exit 1
fi

# Check that the processor is 64 bit
if [[ $(getconf LONG_BIT) != 64 ]]; then
    echo -e "${RED}This is not a 64-bit processor VPS. Exiting...${NC}"
    exit 1
fi

# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "${RED}Program systemd could not be found. Exiting...${NC}"  >&2; exit 1; }

echo -e "${GREEN}"
echo "                                                                    "
echo "                                                                    "
echo "                                                                    "
echo "                            ###########                             "
echo "                        ##################                          "
echo "                       #####################                        "
echo "                      #########     #########                       "
echo "                     #######           #######                      "
echo "                    #######             #######                     "
echo "                    ######               ######                     "
echo "                    ######                                          "
echo "                  ###############################                   "
echo "              #############             ##############              "
echo "          #######   ######    ######            #########           "
echo "         ######     ######   ##################     ######          "
echo "         ######     ######   ##################     ######          "
echo "          #######   ######    ######    ####### #########           "
echo "             ##############             ##############              "
echo "                  ###############################                   "
echo "                    ######              #######                     "
echo "                    #######             #######                     "
echo "                     #######          #########                     "
echo "                      #########################                     "
echo "                        ################ ######                     "
echo "                          ############     ####                     "
echo "                                                                    "
echo "                                                                    "
echo "                                                                    "
echo -e "${NC}"
echo "********************************************************************"
echo " This script will install and configure your Galactrum masternode. "
echo "********************************************************************"
echo " Pressing ENTER will use the default value for the next prompts. "
echo "********************************************************************"
echo -e "${RED} Make sure you double check before hitting enter!${NC}"
echo "********************************************************************"
echo && sleep 3

function clearBuffer {
    # This function will be used to clear STDIN buffer from keyboard inputs
    while read -r -t 0
    do
        read -r
    done
}

function stopDaemon {
    # This function will be used to stop the Galactrum daemon if it is running
    if (pgrep -x 'galactrumd' > /dev/null); then
        echo -e "${YELLOW}Galactrum daemon is running. Attempting to stop...${NC}"
        /usr/local/bin/galactrum-cli -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum stop
        sleep 5
        if (pgrep -x 'galactrumd' > /dev/null); then
            echo -e "${YELLOW}Galactrum daemon is still running. Attempting to kill process...${NC}"
            pkill galactrumd
            sleep 2
            if (pgrep -x 'galactrumd' > /dev/null); then
                echo -e "${RED}Unable to stop the daemon! Exiting...${NC}"
                kill 1
            fi
        fi
        clearBuffer
    fi
}

clearBuffer

# Server IP address
publicIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
if [[ -n $publicIP && $publicIP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo -e "${GREEN}IP address was detected: ${publicIP}${NC}"
else
    echo -e "${YELLOW}Public IP address could not be detected!\a${NC}"
    read -e -p "Enter the server IP address : " publicIP
    if [[ -z $publicIP || ! $publicIP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "${RED}This is not a valid IP address. Exiting...${NC}"
    fi
fi
        
# Masternode Private Key
function request_key {
    read -e -p "Would you like me to generate a masternode private key? [Y/n] : " privKeyBool
    if [[ $privKeyBool == "n" || $privKeyBool == "N" ]]; then
        read -e -p "Enter your masternode private key (e.g. 7edfjLCUzGczZi3JQw8GHp434R9kNY33eFyMGeKRymkB56G4324h) : " key
        read -e -p "Confirm your masternode private key : " key2
        if [[ $key == $key2 ]]; then
            echo -e "${GREEN}The masternode private keys matched!${NC}"
        fi
    elif [[ $privKeyBool == "y" || $privKeyBool == "Y" || $privKeyBool == "" ]]; then
        echo -e "${YELLOW}A masternode private key will be generated.${NC}"
        key=""
    else
        echo -e "${RED}This is not an expected entry. Exiting...${NC}"
        exit 1
    fi
}

request_key
while [[ ( $privKeyBool == "n" || $privKeyBool == "N"  ) && $key != $key2 ]]
do
    echo -e "${YELLOW}The masternode private keys did not match! Please try again.${NC}";
    request_key
done

# Swap space prompt
read -e -p "Add swap space? (Recommended) [Y/n] : " add_swap
if [[ ( "$add_swap" == "y" || "$add_swap" == "Y" || "$add_swap" == "" ) ]]; then
    if [ -f /swapfile ]; then
        echo -e "${YELLOW}A swap file already exists on this server. Skipping swap file...${NC}"
        add_swap="N"
    else
        read -e -p "Swap Size [2G] : " swap_size
        if [[ "$swap_size" == "" ]]; then
            swap_size="2G"
        fi
    fi
fi    

# fail2ban prompt
read -e -p "Install Fail2ban? (Recommended) [Y/n] : " install_fail2ban
if [[ ( "$install_fail2ban" == "y" || "$install_fail2ban" == "Y" || "$install_fail2ban" == "" ) ]]; then
    if [[ -d "/var/lib/fail2ban" ]]; then
        echo -e "${YELLOW}fail2ban is already installed on this server. Skipping fail2ban installation...${NC}"
        install_fail2ban="N"
    fi
fi

# UFW prompt
read -e -p "Install UFW (Firewall) and configure ports? (Recommended) [Y/n] : " UFW
if [[ ( "$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "" ) ]]; then
    if (type "ufw" > /dev/null); then
        echo -e "${YELLOW}UFW is already installed on this server. Skipping UFW installation...${NC}"
        echo && echo -e "Configuring UFW..."
        sleep 3
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw allow ssh
        sudo ufw allow ${P2P_PORT}/tcp
        echo "y" | sudo ufw enable
        echo -e "${GREEN}UFW configuration completed!${NC}"
        UFW="N"
    fi
fi

# Add swap if needed
if [[ ( "$add_swap" == "y" || "$add_swap" == "Y" || "$add_swap" == "" ) ]]; then
    echo && echo -e "Adding swap space..."
    sleep 3
    sudo fallocate -l $swap_size /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    sudo sysctl vm.swappiness=10
    sudo sysctl vm.vfs_cache_pressure=50
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
    echo -e "${GREEN}Swap file creation completed!${NC}"
fi

# Install fail2ban if needed
if [[ ( "$install_fail2ban" == "y" || "$install_fail2ban" == "Y" || "$install_fail2ban" == "" ) ]]; then
    echo && echo "Installing fail2ban..."
    sleep 3
    sudo apt-get -y install fail2ban
    sudo service fail2ban restart 
    echo -e "${GREEN}fail2ban installation completed!${NC}"
fi

# Install firewall if needed
if [[ ( "$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "" ) ]]; then
    echo && echo "Installing UFW..."
    sleep 3
    sudo apt-get -y install ufw
    echo && echo "Configuring UFW..."
    sleep 3
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow ${P2P_PORT}/tcp
    echo "y" | sudo ufw enable
    echo -e "${GREEN}UFW installation and configuraton completed!${NC}"
fi

# Update system 
echo && echo "Updating system..."
sleep 3
sudo apt-get -y update
sudo apt-get -y upgrade
echo -e "${GREEN}System update completed!${NC}"

# Add Berkely PPA
echo && echo "Installing bitcoin PPA..."
sleep 3
sudo apt-get -y install software-properties-common
sudo apt-add-repository -y ppa:bitcoin/bitcoin
sudo apt-get -y update

# Install required packages
echo && echo "Installing base packages..."
sleep 3
sudo apt-get -y install \
    wget \
    git \
    libevent-dev \
    libboost-dev \
    libboost-chrono-dev \
    libboost-filesystem-dev \
    libboost-program-options-dev \
    libboost-system-dev \
    libboost-test-dev \
    libboost-thread-dev \
    libdb4.8-dev \
    libdb4.8++-dev \
    libminiupnpc-dev 
echo -e "${GREEN}Base packages installation completed!${NC}"

# Download Galactrum
echo && echo -e "Downloading Galactrum v${WALLET_VERSION} for Ubuntu${UBUNTU_RELEASE}..."
sleep 3
wget ${WALLET_LINK}
tar -xvf ${WALLET_ZIP}
rm ${WALLET_ZIP}

# Install Galactrum
echo && echo -e "Installing Galactrum v${WALLET_VERSION}..."
sleep 3
sudo chmod 755 ${WALLET_FOLDER}/bin/galactrum*
sudo mv ${WALLET_FOLDER}/bin/galactrum{d,-cli} /usr/local/bin
echo -e "${GREEN}Gallactrum installation completed!${NC}"

# Add masternode group and user
sudo groupadd masternode
sudo useradd -m -g masternode masternode

# Create data dir and config file
sudo mkdir -p /home/masternode/.galactrum
sudo touch /home/masternode/.galactrum/galactrum.conf
sudo chown -R masternode:masternode /home/masternode/.galactrum

# Setup systemd service
echo && echo "Creating Galactrum service..."
sleep 3
sudo touch /etc/systemd/system/galactrumd.service
echo '[Unit]
Description=galactrumd
After=network.target

[Service]
Type=simple
User=masternode
WorkingDirectory=/home/masternode
ExecStart=/usr/local/bin/galactrumd -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum
ExecStop=/usr/local/bin/galactrum-cli -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum stop
Restart=on-abort

[Install]
WantedBy=multi-user.target
' | sudo -E tee /etc/systemd/system/galactrumd.service
echo -e "${GREEN}Gallactrum service completed!${NC}"

# Create config for Galactrum
echo && echo -e "Configuring Galactrum v${WALLET_VERSION}..."
# Generate random user and password
rpcuser=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
rpcpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
echo 'rpcuser='$rpcuser'
rpcpassword='$rpcpassword'' > /home/masternode/.galactrum/galactrum.conf

sleep 3
# If private key is needed, start wallet and generate one
if [[ $privKeyBool == "y" || $privKeyBool == "Y" || $privKeyBool == "" ]]; then
    key=""
    echo -e "${YELLOW}Generating masternode private key...${NC}"
    sudo systemctl start galactrumd.service
    echo "Wallet is loading..."
    sleep 10
    key=$( galactrum-cli -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum masternode genkey )
    if [[ -z $key ]]; then
        echo -e "${YELLOW}Wallet is still loading. Trying again in 10 seconds...${NC}"
        sleep 10
        key=$( galactrum-cli -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum masternode genkey )
    fi
    if [[ -z $key ]]; then
        echo -e "${YELLOW}Wallet is still loading. Trying again in 10 seconds...${NC}"
        sleep 10
        key=$( galactrum-cli -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum masternode genkey )
    fi
    if [[ -z $key ]]; then
        echo -e "${YELLOW}Wallet is still loading. Trying again in 10 seconds...${NC}"
        sleep 10
        key=$( galactrum-cli -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum masternode genkey )
    fi
    if [[ -z $key ]]; then
        echo -e "${RED}4 attempts to generate masternode private key failed! Exiting...${NC}"
        exit 1
    fi
    echo -e "${GREEN}Masternode private key generated!${NC}"
    clearBuffer
fi

sudo systemctl stop galactrumd.service
stopDaemon # Extra check
sleep 3

echo 'rpcallowip=127.0.0.1
listen=1
server=1
daemon=0 # required for systemd
logtimestamps=1
maxconnections=256
externalip='$publicIP'
masternode=1
masternodeprivkey='$key'' >> /home/masternode/.galactrum/galactrum.conf
echo -e "${GREEN}Gallactrum configuration completed!${NC}"

echo && echo "Starting Galactrum Daemon..."
sudo systemctl enable galactrumd.service
sudo systemctl start galactrumd.service
echo -e "${GREEN}Daemon has been started!${NC}"

# Add alias to run galactrum-cli
touch ~/.bash_aliases
echo "alias galactrum-cli='galactrum-cli -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum'" >> ~/.bash_aliases

# Download and install sentinel
echo && echo "Installing Sentinel..."
sleep 3
sudo apt-get -y install virtualenv python-pip
sudo git clone https://github.com/galactrum/sentinel /home/masternode/sentinel
cd /home/masternode/sentinel
virtualenv venv
. venv/bin/activate
pip install -r requirements.txt
export EDITOR=nano
(crontab -l -u masternode 2>/dev/null; echo '* * * * * cd /home/masternode/sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1') | sudo crontab -u masternode -
sudo chown -R masternode:masternode /home/masternode/sentinel
echo "galactrum_conf=/home/masternode/.galactrum/galactrum.conf" >> /home/masternode/sentinel/test/test_sentinel.conf
echo -e "${GREEN}Sentinel has been installed and configured!${NC}"
cd ~

sleep 5
clear
echo -e "********************************************************************
${GREEN}Masternode setup completed!${NC}
********************************************************************
Masternode VPS IP address: ${GREEN}$publicIP${NC}
Masternode private key: ${GREEN}$key${NC}
\nPlease add the following line to your local masternode.conf file:
${YELLOW}ALIAS${NC} $publicIP:$P2P_PORT $key ${YELLOW}TXID VOUT${NC}
\nWhere:\n${YELLOW}ALIAS${NC}: The name you want to give your masternode
${YELLOW}TXID${NC}: The transaction ID of the 1,000 ORE collateral
${YELLOW}VOUT${NC}: The transaction index of the 1,000 ORE collateral
\nYou can get TXID and VOUT by doing ${GREEN}masternode outputs${NC} in the local wallet console
Note: You can copy the above line by selecting it, then pressing Ctrl+Insert.
      You can paste the line in your masternode.conf by pressing Shift+Insert.
\nOnce added to the masternode.conf file, restart the wallet.
********************************************************************"
clearBuffer
read -p "Press Enter to continue..." -s

while sleep 1; do
if [[ $( galactrum-cli -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum mnsync status | grep "IsBlockchainSynced" ) = *true* ]]; then
    IsBlockchainSynced=true
else
    IsBlockchainSynced=false
fi
if [[ $( galactrum-cli -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum mnsync status | grep "IsMasternodeListSynced" ) = *true* ]]; then
    IsMasternodeListSynced=true
else
    IsMasternodeListSynced=false
fi
if [[ $( galactrum-cli -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum mnsync status | grep "IsWinnersListSynced" ) = *true* ]]; then
    IsWinnersListSynced=true
else
    IsWinnersListSynced=false
fi
if [[ $( galactrum-cli -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum mnsync status | grep "IsSynced" ) = *true* ]]; then
    IsSynced=true
else
    IsSynced=false
fi
if [[ $( galactrum-cli -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum mnsync status | grep "IsFailed" ) = *true* ]]; then
    IsFailed=true
else
    IsFailed=false
fi
blockHeight=$(galactrum-cli -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum getblockcount)
masternodeStatus=$(galactrum-cli -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum masternode status | grep "status")
clear
echo "********************************************************************"
uptime
echo "********************************************************************"
echo -e "Please wait until the status below turns ${GREEN}green${NC} before starting the masternode!\n"
echo "Block number: $blockHeight"
if [[ "$IsBlockchainSynced" = true ]]; then
    echo -e "IsBlockchainSynced: ${GREEN}true${NC}"
else
    echo -e "IsBlockchainSynced: ${YELLOW}false${NC}"
fi
if [[ "$IsMasternodeListSynced" = true ]]; then
    echo -e "IsMasternodeListSynced: ${GREEN}true${NC}"
else
    echo -e "IsMasternodeListSynced: ${YELLOW}false${NC}"
fi
if [[ "$IsWinnersListSynced" = true ]]; then
    echo -e "IsWinnersListSynced: ${GREEN}true${NC}"
else
    echo -e "IsWinnersListSynced: ${YELLOW}false${NC}"
fi
if [[ "$IsSynced" = true ]]; then
    echo -e "IsSynced: ${GREEN}true${NC}"
else
    echo -e "IsSynced: ${YELLOW}false${NC}"
fi
if [[ "$IsFailed" = true ]]; then
    echo -e "IsFailed: ${YELLOW}true${NC}"
else
    echo -e "IsFailed: ${GREEN}false${NC}"
fi

echo -e "\n********************************************************************"
echo -e "Ensure your collateral transaction has 15 confirmations before starting the masternode."
echo -e "Once you start the masternode from the control wallet, monitor the status below:\n"
if [[ "$masternodeStatus" = *successfully* ]];then
    echo -e "  \"status\": ${GREEN}\"Masternode successfully started\"${NC}"
else
    echo "$masternodeStatus"
fi
echo -e "\n********************************************************************"
echo "Note: run the command 'source ~/.bash_aliases' to use galactrum-cli."

echo -e "\n\nPress Ctrl-C to exit..."
done
