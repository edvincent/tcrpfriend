#!/usr/bin/env bash

##### explanation ###################################################################################
# As you edit the cmdline of grub.cfg
# Edit /mnt/tcrp/user_config.json to modify cmdline used by TCRP FRIEND
#####################################################################################################

TMP_PATH=/tmp
LOG_FILE="${TMP_PATH}/log.txt"
USER_CONFIG_FILE="/mnt/tcrp/user_config.json"

MODEL=$(jq -r -e '.general.model' "$USER_CONFIG_FILE")
BUILD=$(jq -r -e '.general.version' "$USER_CONFIG_FILE" | cut -c 7-)
SN=$(jq -r -e '.extra_cmdline.sn' "$USER_CONFIG_FILE")
MACADDR1=$(jq -r -e '.extra_cmdline.mac1' "$USER_CONFIG_FILE")
NETNUM="1"

LAYOUT=$(jq -r -e '.general.layout' "$USER_CONFIG_FILE")
KEYMAP=$(jq -r -e '.general.keymap' "$USER_CONFIG_FILE")

DMPM=$(jq -r -e '.general.devmod' "$USER_CONFIG_FILE")
LDRMODE=$(jq -r -e '.general.loadermode' "$USER_CONFIG_FILE")
  
###############################################################################
# Write to json config file
function writeConfigKey() {

    block="$1"
    field="$2"
    value="$3"

    if [ -n "$1 " ] && [ -n "$2" ]; then
        jsonfile=$(jq ".$block+={\"$field\":\"$value\"}" $USER_CONFIG_FILE)
        echo $jsonfile | jq . >$USER_CONFIG_FILE
    else
        echo "No values to update specified"
    fi

}

###############################################################################
# Delete field from json config file
function DeleteConfigKey() {

    block="$1"
    field="$2"

    if [ -n "$1 " ] && [ -n "$2" ]; then
        jsonfile=$(jq "del(.$block.$field)" $USER_CONFIG_FILE)
        echo $jsonfile | jq . >$USER_CONFIG_FILE
    else
        echo "No values to remove"
    fi

}


###############################################################################
# Mounts backtitle dynamically
function backtitle() {
  BACKTITLE="TCRP 0.9.4.3-1"
  BACKTITLE+=" ${DMPM}"
  BACKTITLE+=" ${LDRMODE}"
  if [ -n "${MODEL}" ]; then
    BACKTITLE+=" ${MODEL}"
  else
    BACKTITLE+=" (no model)"
  fi
  if [ -n "${BUILD}" ]; then
    BACKTITLE+=" ${BUILD}"
  else
    BACKTITLE+=" (no build)"
  fi
  if [ -n "${SN}" ]; then
    BACKTITLE+=" ${SN}"
  else
    BACKTITLE+=" (no SN)"
  fi
  if [ -n "${MACADDR1}" ]; then
    BACKTITLE+=" ${MACADDR1}"
  else
    BACKTITLE+=" (no MAC1)"
  fi
  if [ -n "${MACADDR2}" ]; then
    BACKTITLE+=" ${MACADDR2}"
  else
    BACKTITLE+=" (no MAC2)"
  fi
  if [ -n "${MACADDR3}" ]; then
    BACKTITLE+=" ${MACADDR3}"
  else
    BACKTITLE+=" (no MAC3)"
  fi
  if [ -n "${MACADDR4}" ]; then
    BACKTITLE+=" ${MACADDR4}"
  else
    BACKTITLE+=" (no MAC4)"
  fi
  if [ -n "${KEYMAP}" ]; then
    BACKTITLE+=" (${LAYOUT}/${KEYMAP})"
  else
    BACKTITLE+=" (qwerty/us)"
  fi
  echo ${BACKTITLE}
}

###############################################################################
# Shows menu to user type one or generate randomly
function serialMenu() {
      while true; do
        dialog --backtitle "`backtitle`" \
          --inputbox "Please enter a serial number " 0 0 "" \
          2>${TMP_PATH}/resp
        [ $? -ne 0 ] && return
        SERIAL=`cat ${TMP_PATH}/resp`
        if [ -z "${SERIAL}" ]; then
          return
        else
          break
        fi
      done
  SN="${SERIAL}"
  writeConfigKey "extra_cmdline" "sn" "${SN}"
}

###############################################################################
# Shows menu to generate randomly or to get realmac
function macMenu() {
      while true; do
        dialog --backtitle "`backtitle`" \
          --inputbox "Please enter a mac address " 0 0 "" \
          2>${TMP_PATH}/resp
        [ $? -ne 0 ] && return
        MACADDR=`cat ${TMP_PATH}/resp`
        if [ -z "${MACADDR}" ]; then
          return
        else
          break
        fi
      done
  
  if [ "$1" = "eth0" ]; then
      MACADDR1="${MACADDR}"
      writeConfigKey "extra_cmdline" "mac1" "${MACADDR1}"
  fi
  
  if [ "$1" = "eth1" ]; then
      MACADDR2="${MACADDR}"
      writeConfigKey "extra_cmdline" "mac2" "${MACADDR2}"
      writeConfigKey "extra_cmdline" "netif_num" "2"
  fi
  
  if [ "$1" = "eth2" ]; then
      MACADDR3="${MACADDR}"
      writeConfigKey "extra_cmdline" "mac3" "${MACADDR3}"
      writeConfigKey "extra_cmdline" "netif_num" "3"
  fi

  if [ "$1" = "eth3" ]; then
      MACADDR4="${MACADDR}"
      writeConfigKey "extra_cmdline" "mac4" "${MACADDR4}"
      writeConfigKey "extra_cmdline" "netif_num" "4"
  fi

}

###############################################################################
# Permits user edit the user config
function editUserConfig() {
  while true; do
    dialog --backtitle "`backtitle`" --title "Edit with caution" \
      --editbox "${USER_CONFIG_FILE}" 0 0 2>"${TMP_PATH}/userconfig"
    [ $? -ne 0 ] && return
    mv "${TMP_PATH}/userconfig" "${USER_CONFIG_FILE}"
    [ $? -eq 0 ] && break
    dialog --backtitle "`backtitle`" --title "Invalid JSON format" --msgbox "${ERRORS}" 0 0
  done

  MODEL="$(jq -r -e '.general.model' $USER_CONFIG_FILE)"
  SN="$(jq -r -e '.extra_cmdline.sn' $USER_CONFIG_FILE)"
  MACADDR1="$(jq -r -e '.extra_cmdline.mac1' $USER_CONFIG_FILE)"
  MACADDR2="$(jq -r -e '.extra_cmdline.mac2' $USER_CONFIG_FILE)"
  MACADDR3="$(jq -r -e '.extra_cmdline.mac3' $USER_CONFIG_FILE)"
  MACADDR4="$(jq -r -e '.extra_cmdline.mac4' $USER_CONFIG_FILE)"
  NETNUM"=$(jq -r -e '.extra_cmdline.netif_num' $USER_CONFIG_FILE)"
}

function checkUserConfig() {

  netif_num=$(jq -r -e '.extra_cmdline.netif_num' $USER_CONFIG_FILE)
  netif_num_cnt=$(cat $USER_CONFIG_FILE | grep \"mac | wc -l)
                    
  if [ $netif_num != $netif_num_cnt ]; then
    echo "netif_num = ${netif_num}"
    echo "number of mac addresses = ${netif_num_cnt}"       
    echo "The netif_num and the number of mac addresses do not match. Check user_config.json again. Abort the loader build !!!!!! "
    echo "press any key to continue..."                                                                                                   
    read answer
    return 1     
  fi  

}

function boot() {
    checkUserConfig
    ./boot.sh
    break
}

# Main function loop
function mainmenu() {
  
  if [ $(ifconfig | grep eth1 | wc -l) -gt 0 ]; then
    MACADDR2="$(jq -r -e '.extra_cmdline.mac2' $USER_CONFIG_FILE)"
    NETNUM="2"
  fi  
  if [ $(ifconfig | grep eth2 | wc -l) -gt 0 ]; then
    MACADDR3="$(jq -r -e '.extra_cmdline.mac3' $USER_CONFIG_FILE)"
    NETNUM="3"
  fi  
  if [ $(ifconfig | grep eth3 | wc -l) -gt 0 ]; then
    MACADDR4="$(jq -r -e '.extra_cmdline.mac4' $USER_CONFIG_FILE)"
    NETNUM="4"
  fi  

  CURNETNUM="$(jq -r -e '.extra_cmdline.netif_num' $USER_CONFIG_FILE)"
  if [ $CURNETNUM != $NETNUM ]; then
    if [ $NETNUM == "3" ]; then 
      DeleteConfigKey "extra_cmdline" "mac4"
    fi  
    if [ $NETNUM == "2" ]; then 
      DeleteConfigKey "extra_cmdline" "mac4"  
      DeleteConfigKey "extra_cmdline" "mac3"
    fi  
    if [ $NETNUM == "1" ]; then
      DeleteConfigKey "extra_cmdline" "mac4"  
      DeleteConfigKey "extra_cmdline" "mac3"
      DeleteConfigKey "extra_cmdline" "mac2"    
    fi  
    writeConfigKey "extra_cmdline" "netif_num" "$NETNUM"
  fi

  NEXT="m"
  while true; do

    echo "s \"Enter a Synology Serial Number\""         > "${TMP_PATH}/menu"
    echo "a \"Enter a mac address 1\""                 >> "${TMP_PATH}/menu"
    if [ $(ifconfig | grep eth1 | wc -l) -gt 0 ]; then
      echo "f \"Enter a mac address 2\""               >> "${TMP_PATH}/menu"
    fi  
    if [ $(ifconfig | grep eth2 | wc -l) -gt 0 ]; then
      echo "g \"Enter a mac address 3\""               >> "${TMP_PATH}/menu"
    fi  
    if [ $(ifconfig | grep eth3 | wc -l) -gt 0 ]; then
      echo "h \"Enter a mac address 4\""               >> "${TMP_PATH}/menu"
    fi
    echo "u \"Edit user config file manually\""         >> "${TMP_PATH}/menu"
    echo "r \"continue boot\""                          >> "${TMP_PATH}/menu"

    dialog --clear --default-item ${NEXT} --backtitle "`backtitle`" --colors \
      --menu "As you edit the cmdline of grub.cfg/nEdit /mnt/tcrp/user_config.json to modify cmdline used by TCRP FRIEND" 0 0 0 --file "${TMP_PATH}/menu" \
      2>${TMP_PATH}/resp
    [ $? -ne 0 ] && break
    case `<"${TMP_PATH}/resp"` in
      s) serialMenu;      NEXT="a" ;;
      a) macMenu "eth0"
        if [ $(ifconfig | grep eth1 | wc -l) -gt 0 ]; then
            NEXT="f" 
	      else
            NEXT="r" 	
	      fi
        ;;
      f) macMenu "eth1"
        if [ $(ifconfig | grep eth2 | wc -l) -gt 0 ]; then
            NEXT="g" 
	      else
            NEXT="r" 	
	      fi
        ;;
      g) macMenu "eth2"
        if [ $(ifconfig | grep eth3 | wc -l) -gt 0 ]; then
            NEXT="h" 
	      else
            NEXT="r" 	
	      fi
        ;;
      h) macMenu "eth3";    NEXT="r" ;;    
      u) editUserConfig;    NEXT="r" ;;
      r) boot ;;
      e) break ;;
    esac
  done

}    
