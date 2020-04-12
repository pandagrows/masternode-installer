#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="seed2need.conf"
SEED2NEED_DAEMON="/usr/local/bin/seed2needd"
SEED2NEED_CLI="/usr/local/bin/seed2need-cli"
SEED2NEED_REPO="https://github.com/pandagrows/seed2need-farm-coin.git"
SEED2NEED_LATEST_RELEASE="https://github.com/pandagrows/seed2need-farm-coin/releases/download/v1.0.0/seed2need-1.0.0-ubuntu-18.04-daemon.zip"
COIN_BOOTSTRAP='https://bootstrap.seed2need.me/farm_boot_strap.tar.gz'
COIN_ZIP=$(echo $SEED2NEED_LATEST_RELEASE | awk -F'/' '{print $NF}')
COIN_CHAIN=$(echo $COIN_BOOTSTRAP | awk -F'/' '{print $NF}')

DEFAULT_SEED2NEED_PORT=2020
DEFAULT_SEED2NEED_RPC_PORT=2021
DEFAULT_SEED2NEED_USER="seed2need"
SEED2NEED_USER="seed2need"
NODE_IP=NotCheckedYet
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

purgeOldInstallation() {
    echo -e "${GREEN}Searching and removing old $COIN_NAME Daemon{NC}"
    #kill wallet daemon
	systemctl stop $SEED2NEED_USER.service
	
	#Clean block chain for Bootstrap Update
    cd $CONFIGFOLDER >/dev/null 2>&1
    rm -rf *.pid *.lock database sporks chainstate zerocoin blocks >/dev/null 2>&1
	
    #remove binaries and Seed2need utilities
    cd /usr/local/bin && sudo rm seed2need-cli seed2need-tx seed2needd > /dev/null 2>&1 && cd
    echo -e "${GREEN}* Done${NONE}";
}


function download_bootstrap() {
  echo -e "${GREEN}Downloading and Installing $COIN_NAME BootStrap${NC}"
  mkdir -p /root/tmp
  cd /root/tmp >/dev/null 2>&1
  rm -rf boot_strap* >/dev/null 2>&1
  wget -q $COIN_BOOTSTRAP
  cd $CONFIGFOLDER >/dev/null 2>&1
  rm -rf *.pid *.lock database sporks chainstate zerocoin blocks >/dev/null 2>&1
  cd /root/tmp >/dev/null 2>&1
  tar -zxf $COIN_CHAIN /root/tmp >/dev/null 2>&1
  cp -Rv cache/* $CONFIGFOLDER >/dev/null 2>&1
  cd ~ >/dev/null 2>&1
  rm -rf $TMP_FOLDER >/dev/null 2>&1
  clear
}

function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *18.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 18.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $SEED2NEED_DAEMON)" ] || [ -e "$SEED2NEED_DAEMON" ] ; then
  echo -e "${GREEN}\c"
  echo -e "Seed2need is already installed. Exiting..."
  echo -e "{NC}"
  exit 1
fi
}


function copy_seed2need_binaries(){
  cd /root
  wget $SEED2NEED_LATEST_RELEASE
  unzip seed2need-1.0.0-ubuntu-18.04-daemon.zip
  cp seed2need-cli seed2needd seed2need-tx /usr/local/bin >/dev/null
  chmod 755 /usr/local/bin/seed2need* >/dev/null
  clear
}

function install_seed2need(){
  echo -e "Installing Seed2need files."
  copy_seed2need_binaries
  clear
}


function systemd_seed2need() {
sleep 2
systemctl start $SEED2NEED_USER.service
}


function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "Seed2need Masternode Upgraded to the Latest Version{NC}"
 echo -e "Commands to Interact with the service are listed below{NC}"
 echo -e "Start: ${RED}systemctl start $SEED2NEED_USER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $SEED2NEED_USER.service${NC}"
 echo -e "Please check Seed2need is running with the following command: ${GREEN}systemctl status $SEED2NEED_USER.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
	download_bootstrap
	systemd_seed2need
	important_information
}


##### Main #####
clear
purgeOldInstallation
checks
install_seed2need

