#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="circuit.conf"
CIRCUIT_DAEMON="/usr/local/bin/circuitd"
CIRCUIT_CLI="/usr/local/bin/circuit-cli"
CIRCUIT_REPO="https://github.com/CircuitProject/Circuit-Project.git"
CIRCUIT_LATEST_RELEASE="https://github.com/CircuitProject/Circuit-Project/releases/download/v1.0.5/circuit-1.0.5-ubuntu1804-daemon.zip"
COIN_BOOTSTRAP='https://bootstrap.circuit-society.io/boot_strap.tar.gz'
COIN_ZIP=$(echo $CIRCUIT_LATEST_RELEASE | awk -F'/' '{print $NF}')
COIN_CHAIN=$(echo $COIN_BOOTSTRAP | awk -F'/' '{print $NF}')

DEFAULT_CIRCUIT_PORT=31350
DEFAULT_CIRCUIT_RPC_PORT=31351
DEFAULT_CIRCUIT_USER="circuit"
CIRCUIT_USER="circuit"
NODE_IP=NotCheckedYet
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

purgeOldInstallation() {
    echo -e "${GREEN}Searching and removing old $COIN_NAME Daemon{NC}"
    #kill wallet daemon
	systemctl stop $CIRCUIT_USER.service
	
	#Clean block chain for Bootstrap Update
    cd $CONFIGFOLDER >/dev/null 2>&1
    rm -rf *.pid *.lock database sporks chainstate zerocoin blocks >/dev/null 2>&1
	
    #remove binaries and Circuit utilities
    cd /usr/local/bin && sudo rm circuit-cli circuit-tx circuitd > /dev/null 2>&1 && cd
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

if [ -n "$(pidof $CIRCUIT_DAEMON)" ] || [ -e "$CIRCUIT_DAEMON" ] ; then
  echo -e "${GREEN}\c"
  echo -e "Circuit is already installed. Exiting..."
  echo -e "{NC}"
  exit 1
fi
}


function copy_circuit_binaries(){
  cd /root
  wget $CIRCUIT_LATEST_RELEASE
  unzip circuit-1.0.5-ubuntu1804-daemon.zip
  cp circuit-cli circuitd circuit-tx /usr/local/bin >/dev/null
  chmod 755 /usr/local/bin/circuit* >/dev/null
  clear
}

function install_circuit(){
  echo -e "Installing Circuit files."
  copy_circuit_binaries
  clear
}


function systemd_circuit() {
sleep 2
systemctl start $CIRCUIT_USER.service
}


function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "Circuit Masternode Upgraded to the Latest Version{NC}"
 echo -e "Commands to Interact with the service are listed below{NC}"
 echo -e "Start: ${RED}systemctl start $CIRCUIT_USER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $CIRCUIT_USER.service${NC}"
 echo -e "Please check Circuit is running with the following command: ${GREEN}systemctl status $CIRCUIT_USER.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
	download_bootstrap
	systemd_circuit
	important_information
}


##### Main #####
clear
purgeOldInstallation
checks
install_circuit

