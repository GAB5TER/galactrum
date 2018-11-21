#!/bin/bash

# Define color coding
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'


echo && echo -e "Stopping existing daemon..."
sudo systemctl stop galactrumd
sleep 2

echo && echo -e "Downloading and installing Galactrum v1.2.1..."
wget https://github.com/galactrum/galactrum/releases/download/v1.2.1/galactrum-1.2.1-linux64.tar.gz
tar -xvf galactrum-1.2.1-linux64.tar.gz
sudo mv galactrum-1.2.1/bin/galactrum{d,-cli} /usr/local/bin
sudo rm galactrum-1.2.1-linux64.tar.gz
echo -e "${GREEN}Gallactrum installation completed!${NC}"

echo && echo -e "Starting daemon and reindexing..."
/usr/local/bin/galactrumd -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum -daemon -reindex
sleep 5
/usr/local/bin/galactrum-cli -conf=/home/masternode/.galactrum/galactrum.conf -datadir=/home/masternode/.galactrum stop
sleep 5
sudo systemctl start galactrumd

echo && echo "Installing Sentinel..."
rm -rf /home/masternode/sentinel
git clone https://github.com/galactrum/sentinel /home/masternode/sentinel
echo -e "${GREEN}Sentinel has been installed and configured!${NC}"

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
if [[ "$IsFailed" = true ]]; then
    echo -e "IsFailed: ${YELLOW}true${NC}"
else
    echo -e "IsFailed: ${GREEN}false${NC}"
fi

echo -e "\n********************************************************************"
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
