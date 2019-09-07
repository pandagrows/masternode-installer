#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="circuit.conf"
CIRCUIT_DAEMON="/usr/local/bin/circuitd"
CIRCUIT_CLI="/usr/local/bin/circuit-cli"
CIRCUIT_REPO="https://github.com/CircuitProject/Circuit-Project.git"
CIRCUIT_LATEST_RELEASE="https://github.com/CircuitProject/Circuit-Project/releases/download/v1.0.1/circuit-daemon-1.0.1-linux.zip"
COIN_BOOTSTRAP='https://bootstrap.circuit-society.io/boot_strap.tar.gz'
COIN_ZIP=$(echo $CIRCUIT_LATEST_RELEASE | awk -F'/' '{print $NF}')
COIN_CHAIN=$(echo $COIN_BOOTSTRAP | awk -F'/' '{print $NF}')

DEFAULT_CIRCUIT_PORT=31350
DEFAULT_CIRCUIT_RPC_PORT=31351
DEFAULT_CIRCUIT_USER="circuit"
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
  rm -rf blk* database* txindex* peers.dat
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

function prepare_system() {

echo -e "Prepare the system to install Circuit master node."
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get upgrade >/dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" git make build-essential libtool bsdmainutils autotools-dev autoconf pkg-config automake python3 libssl-dev libgmp-dev libevent-dev libboost-all-dev libdb4.8-dev libdb4.8++-dev ufw fail2ban pwgen curl unzip >/dev/null 2>&1
NODE_IP=$(curl -s4 icanhazip.com)
clear
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt-get -y upgrade"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y git make build-essential libtool bsdmainutils autotools-dev autoconf pkg-config automake python3 libssl-dev libgmp-dev libevent-dev libboost-all-dev libdb4.8-dev libdb4.8++-dev unzip"
    exit 1
fi
clear

}

function ask_yes_or_no() {
  read -p "$1 ([Y]es or [N]o | ENTER): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

function compile_circuit() {
echo -e "Checking if swap space is needed."
PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
SWAP=$(free -g|awk '/^Swap:/{print $2}')
if [ "$PHYMEM" -lt "4" ] && [ -n "$SWAP" ]
  then
    echo -e "${GREEN}Server is running with less than 4G of RAM without SWAP, creating 8G swap file.${NC}"
    SWAPFILE=/swapfile
    dd if=/dev/zero of=$SWAPFILE bs=1024 count=8388608
    chown root:root $SWAPFILE
    chmod 600 $SWAPFILE
    mkswap $SWAPFILE
    swapon $SWAPFILE
    echo "${SWAPFILE} none swap sw 0 0" >> /etc/fstab
else
  echo -e "${GREEN}Server running with at least 4G of RAM, no swap needed.${NC}"
fi
clear
  echo -e "Clone git repo and compile it. This may take some time."
  cd $TMP_FOLDER
  git clone $CIRCUIT_REPO circuit
  cd circuit
  ./autogen.sh
  ./configure
  make
  strip src/circuitd src/circuit-cli src/circuit-tx
  make install
  cd ~
  rm -rf $TMP_FOLDER
  clear
}

function copy_circuit_binaries(){
   cd /root
  wget $CIRCUIT_LATEST_RELEASE
  unzip circuit-daemon-1.0.1-linux.zip
  cp circuit-cli circuitd circuit-tx /usr/local/bin >/dev/null
  chmod 755 /usr/local/bin/circuit* >/dev/null
  clear
}

function install_circuit(){
  echo -e "Installing Circuit files."
  echo -e "${GREEN}You have the choice between source code compilation (slower and requries 4G of RAM or VPS that allows swap to be added), or to use precompiled binaries instead (faster).${NC}"
  if [[ "no" == $(ask_yes_or_no "Do you want to perform source code compilation?") || \
        "no" == $(ask_yes_or_no "Are you **really** sure you want compile the source code, it will take a while?") ]]
  then
    copy_circuit_binaries
    clear
  else
    compile_circuit
    clear
  fi
}

function enable_firewall() {
  echo -e "Installing fail2ban and setting up firewall to allow ingress on port ${GREEN}$CIRCUIT_PORT${NC}"
  ufw allow $CIRCUIT_PORT/tcp comment "Circuit MN port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
  systemctl enable fail2ban >/dev/null 2>&1
  systemctl start fail2ban >/dev/null 2>&1
}

function systemd_circuit() {
  cat << EOF > /etc/systemd/system/$CIRCUIT_USER.service
[Unit]
Description=Circuit service
After=network.target
[Service]
ExecStart=$CIRCUIT_DAEMON -conf=$CIRCUIT_FOLDER/$CONFIG_FILE -datadir=$CIRCUIT_FOLDER
ExecStop=$CIRCUIT_CLI -conf=$CIRCUIT_FOLDER/$CONFIG_FILE -datadir=$CIRCUIT_FOLDER stop
Restart=always
User=$CIRCUIT_USER
Group=$CIRCUIT_USER

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $CIRCUIT_USER.service
  systemctl enable $CIRCUIT_USER.service

  if [[ -z "$(ps axo user:15,cmd:100 | egrep ^$CIRCUIT_USER | grep $CIRCUIT_DAEMON)" ]]; then
    echo -e "${RED}circuitd is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $CIRCUIT_USER.service"
    echo -e "systemctl status $CIRCUIT_USER.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}


function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "Circuit Masternode is up and running as user ${GREEN}$CIRCUIT_USER${NC} and it is listening on port ${GREEN}$CIRCUIT_PORT${NC}."
 echo -e "${GREEN}$CIRCUIT_USER${NC} password is ${RED}$USERPASS${NC}"
 echo -e "Configuration file is: ${RED}$CIRCUIT_FOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $CIRCUIT_USER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $CIRCUIT_USER.service${NC}"
 echo -e "VPS_IP:PORT ${RED}$NODE_IP:$CIRCUIT_PORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$CIRCUIT_KEY${NC}"
 echo -e "Please check Circuit is running with the following command: ${GREEN}systemctl status $CIRCUIT_USER.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
	download_bootstrap
	enable_firewall
	systemd_circuit
	important_information
}


##### Main #####
clear
purgeOldInstallation
checks
install_circuit
setup_node
