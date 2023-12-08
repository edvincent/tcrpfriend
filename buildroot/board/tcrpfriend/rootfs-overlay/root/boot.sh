#!/bin/bash
#
# Author : PeterSuh-Q3
# Date : 231205
# User Variables :
###############################################################################

##### INCLUDES #####################################################################################################
source menufunc.h
#####################################################################################################

BOOTVER="0.0.9m"
FRIENDLOG="/mnt/tcrp/friendlog.log"
AUTOUPDATES="1"

function history() {
    cat <<EOF
    --------------------------------------------------------------------------------------
    0.0.1 Initial Release
    0.0.2 Added the option to disable TCRP Friend auto update. Default if true.
    0.0.3 Added smallfixnumber to display current update version on boot
    0.0.4 Testing 5.x, fixed typo and introduced user config file update and backup
    0.0.5 Added menu function to edit CMDLINE of user_config.json
    0.0.6 Added Getty Console to solve trouble
    0.0.6a Fix Intel CpuFreq Performence Management
    0.0.6b Added mountall success check routine
    0.0.6c Add CONFIG_MQ_IOSCHED_DEADLINE=y, CONFIG_MQ_IOSCHED_KYBER=y, CONFIG_IOSCHED_BFQ=y, CONFIG_BFQ_GROUP_IOSCHED=y
           restore CpuFreq performance tuning settings ( from 0.0.6a )
    0.0.6d Processing without errors related to synoinfo.conf while processing Ramdisk upgrade
    0.0.6e Removed "No space left on device" when copying /mnt/tcrp-p1/rd.gz file during Ramdisk upgrade
    0.0.6f Add Postupdate boot entry to Grub Boot for Jot Postupdate to utilize FRIEND's Ramdisk upgrade
    0.0.6g Recompile for DSM 7.2.0-64551 RC support
    0.0.7  removed custom.gz from partition 1, added static boot option
    0.0.8  Added the detection of EFI and the addition of withefi option to cmdline
           Enhanced the synoinfo key reading to accept multiword keys
           Fixed an a leading space in the synoinfo key reading
    0.0.8a Updated configs to 64570 U1
    0.0.8b Remove Getty Console (apply debug util instead, logs are stored in /mnt/sd#1/logs/jr)
    0.0.8c Change the Github repository used by getstatic module(): The reason is redpill.ko KP issue for Denverton found when patching ramdisk
    0.0.8d Updated configs to remove fake rss info
    0.0.8e Updated configs to remove DSM auto-update loopback block
    0.0.8f dom_szmax 1GB Restore from static size to dynamic setting
    0.0.8g Added retry processing when downloading rp-lkms.zip of ramdisk patch fails
    0.0.8h When performing Ramdisk Patch, check the IP grant status before proceeding. Thanks ExpBox.
    0.0.9  Added IP detection function on multiple ethernet devices
    0.0.9a Added friend kernel 5.15.26 compatible NIC firmware in bulk
           Added ./boot.sh update (new function)
    0.0.9b Updated to add support for 7.2.1-69057
    0.0.9c Added QR code image for port 5000 access
    0.0.9d Bug fixes for Kernel 5 SA6400 Ramdisk patch
    0.0.9e Maintenance of config/_common/v7*/ramdisk-002-init patch for ramdisk patch
    0.0.9f Added new model configs DS1522+(r1000), DS220+(geminilake), DS2419+(denverton), DS423+(geminilake), DS718+(apollolake), RS2423+(v1000)
    0.0.9g Bug fixes for Kernel 5 SA6400-7.2.1-69057 Ramdisk patch #2
    0.0.9h Adjust the partition priority of custom.gz to be used when patching ramdisk (use from the 3rd partition)
    0.0.9i Bug fixes for Kernel 5 SA6400 Kernel patch
    0.0.9j Added MAC address remapping function referring to user_config.json
    0.0.9k Switch to local storage when rp-lkms.zip download fails when ramdisk patch occurs without internet
    0.0.9l Added Reset DSM Password function
    0.0.9m If no internet, skip installing the Python library for QR codes.
    Current Version : ${BOOTVER}
    --------------------------------------------------------------------------------------
EOF
}

function showlastupdate() {
    cat <<EOF
0.0.9a Added friend kernel 5.15.26 compatible NIC firmware in bulk
0.0.9f Added new model configs DS1522+(r1000), DS220+(geminilake), DS2419+(denverton)
       DS423+(geminilake), DS718+(apollolake), RS2423+(v1000)
0.0.9j Added MAC address remapping function referring to user_config.json
0.0.9k Switch to local storage when rp-lkms.zip download fails when ramdisk patch occurs without internet
0.0.9l Added Reset DSM Password function
0.0.9m If no internet, skip installing the Python library for QR codes.
EOF
}

function version() {
    shift 1
    echo $BOOTVER
    [ "$1" == "history" ] && history
}

function msgalert() {
    echo -en "\033[1;31m$1\033[0m"
}
function msgwarning() {
    echo -en "\033[1;33m$1\033[0m"
}
function msgnormal() {
    echo -en "\033[1;32m$1\033[0m"
}

function checkinternet() {

    curl --connect-timeout 5 -skLO https://raw.githubusercontent.com/about.html 2>&1 >/dev/null
    if [ $? -eq 0 ]; then
        INTERNET="ON"
    else
        INTERNET="OFF"
        msgwarning "Error: No internet found, Skip updating friends and installing Python libraries for QR codes!"
    fi

}

function upgradefriend() {

    if [ ! -z "$IP" ]; then

        if [ "${friendautoupd}" = "false" ]; then
            msgwarning "TCRP Friend auto update disabled\n"
            return
        else
            friendwillupdate="1"
        fi

        echo -n "Checking for latest friend -> "
        URL=$(curl --connect-timeout 15 -s --insecure -L https://api.github.com/repos/PeterSuh-Q3/tcrpfriend/releases/latest | jq -r -e .assets[].browser_download_url | grep chksum)
        [ -n "$URL" ] && curl -s --insecure -L $URL -O

        if [ -f chksum ]; then
            FRIENDVERSION="$(grep VERSION chksum | awk -F= '{print $2}')"
            BZIMAGESHA256="$(grep bzImage-friend chksum | awk '{print $1}')"
            INITRDSHA256="$(grep initrd-friend chksum | awk '{print $1}')"
            if [ "$(sha256sum /mnt/tcrp/bzImage-friend | awk '{print $1}')" = "$BZIMAGESHA256" ] && [ "$(sha256sum /mnt/tcrp/initrd-friend | awk '{print $1}')" = "$INITRDSHA256" ]; then
                msgnormal "OK, latest \n"
            else
                msgwarning "Found new version, bringing over new friend version : $FRIENDVERSION \n"
                URLS=$(curl --insecure -s https://api.github.com/repos/PeterSuh-Q3/tcrpfriend/releases/latest | jq -r ".assets[].browser_download_url")
                for file in $URLS; do curl --insecure --location --progress-bar "$file" -O; done
                FRIENDVERSION="$(grep VERSION chksum | awk -F= '{print $2}')"
                BZIMAGESHA256="$(grep bzImage-friend chksum | awk '{print $1}')"
                INITRDSHA256="$(grep initrd-friend chksum | awk '{print $1}')"
                [ "$(sha256sum bzImage-friend | awk '{print $1}')" = "$BZIMAGESHA256" ] && [ "$(sha256sum initrd-friend | awk '{print $1}')" = "$INITRDSHA256" ] && cp -f bzImage-friend /mnt/tcrp/ && msgnormal "bzImage OK! \n"
                [ "$(sha256sum bzImage-friend | awk '{print $1}')" = "$BZIMAGESHA256" ] && [ "$(sha256sum initrd-friend | awk '{print $1}')" = "$INITRDSHA256" ] && cp -f initrd-friend /mnt/tcrp/ && msgnormal "initrd-friend OK! \n"
                msgnormal "TCRP FRIEND HAS BEEN UPDATED, GOING FOR REBOOT\n"
                countdown "REBOOT"
                reboot -f
            fi
        else
            msgalert "No IP yet to check for latest friend \n"
        fi
    fi
}

function getredpillko() {

    if [ ! -n "$IP" ]; then
        msgalert "The getredpillko() cannot proceed because there is no IP yet !!!! \n"
        exit 99
    fi

    cd /root

    echo "Removing any old redpill.ko modules"
    [ -f /root/redpill.ko ] && rm -f /root/redpill.ko

    ORIGIN_PLATFORM=$(cat /mnt/tcrp-p1/GRUB_VER | grep PLATFORM | cut -d "=" -f2 | tr '[:upper:]' '[:lower:]' | sed 's/"//g')
    DSM_VERSION=$(cat /mnt/tcrp-p1/GRUB_VER | grep DSM_VERSION | cut -d "=" -f2 | sed 's/"//g')

    if [ ${DSM_VERSION} -lt 64570 ]; then
        KVER="4.4.180"
    else
        KVER="4.4.302"
    fi

    if [ "${ORIGIN_PLATFORM}" = "epyc7002" ]; then    
        KVER="5.10.55"
    elif [ "${ORIGIN_PLATFORM}" = "bromolow" ]; then
        KVER="3.10.108"        
    fi
    
    echo "KERNEL VERSION of getredpillko() is ${KVER}"
    echo "Downloading ${ORIGIN_PLATFORM} ${KVER}+ redpill.ko ..."
    if [ "${ORIGIN_PLATFORM}" = "epyc7002" ]; then
        v="5"
    else
        v=""
    fi

    LATESTURL="`curl --connect-timeout 5 -skL -w %{url_effective} -o /dev/null "${PROXY}https://github.com/PeterSuh-Q3/redpill-lkm${v}/releases/latest"`"

    if [ $? -ne 0 ]; then
        echo "Error downloading last version of ${ORIGIN_PLATFORM} ${KVER}+ rp-lkms.zip tring other path..."
        curl --connect-timeout 5 -skL https://raw.githubusercontent.com/PeterSuh-Q3/redpill-lkm${v}/master/rp-lkms.zip -o /tmp/rp-lkms${v}.zip
        if [ $? -ne 0 ]; then
            echo "Error downloading https://raw.githubusercontent.com/PeterSuh-Q3/redpill-lkm${v}/master/rp-lkms${v}.zip"
            cp -vf /mnt/tcrp/rp-lkms${v}.zip /tmp/rp-lkms${v}.zip
        fi    
    else
        TAG="${LATESTURL##*/}"
        echo "TAG is ${TAG}"        
        STATUS=`curl --connect-timeout 5 -skL -w "%{http_code}" "${PROXY}https://github.com/PeterSuh-Q3/redpill-lkm${v}/releases/download/${TAG}/rp-lkms.zip" -o "/tmp/rp-lkms${v}.zip"`
    fi

    if [ "${ORIGIN_PLATFORM}" = "epyc7002" ]; then
        unzip /tmp/rp-lkms${v}.zip rp-${ORIGIN_PLATFORM}-${major}.${minor}-${KVER}-prod.ko.gz -d /tmp >/dev/null 2>&1
        gunzip -f /tmp/rp-${ORIGIN_PLATFORM}-${major}.${minor}-${KVER}-prod.ko.gz >/dev/null 2>&1
        cp -vf /tmp/rp-${ORIGIN_PLATFORM}-${major}.${minor}-${KVER}-prod.ko /root/redpill.ko
    else
        unzip /tmp/rp-lkms${v}.zip rp-${ORIGIN_PLATFORM}-${KVER}-prod.ko.gz -d /tmp >/dev/null 2>&1
        gunzip -f /tmp/rp-${ORIGIN_PLATFORM}-${KVER}-prod.ko.gz >/dev/null 2>&1
        cp -vf /tmp/rp-${ORIGIN_PLATFORM}-${KVER}-prod.ko /root/redpill.ko
    fi    

    if [ -f /root/redpill.ko ] && [ -n $(strings /root/redpill.ko | grep -i $model | head -1) ]; then
        echo "Copying redpill.ko module to ramdisk"
        cp /root/redpill.ko /root/rd.temp/usr/lib/modules/rp.ko
    else
        echo "Module does not contain platform information for ${model}"
    fi

    [ -f /root/rd.temp/usr/lib/modules/rp.ko ] && echo "Redpill module is in place"
}

function getstaticmodule() {
    redpillextension="https://github.com/pocopico/rp-ext/raw/main/redpill${redpillmake}/rpext-index.json"
    SYNOMODEL="$(echo $model | sed -e 's/+/p/g' | tr '[:upper:]' '[:lower:]')_${buildnumber}"

    cd /root

    echo "Removing any old redpill.ko modules"
    [ -f /root/redpill.ko ] && rm -f /root/redpill.ko

    extension=$(curl --insecure --silent --location "$redpillextension")

    echo "Looking for redpill for : $SYNOMODEL"

    release=$(echo $extension | jq -r -e --arg SYNOMODEL $SYNOMODEL '.releases[$SYNOMODEL]')
    files=$(curl --insecure --silent --location "$release" | jq -r '.files[] .url')

    for file in $files; do
        echo "Getting file $file"
        curl --insecure --silent -O $file
        if [ -f redpill*.tgz ]; then
            echo "Extracting module"
            gunzip redpill*.tgz
            tar xf redpill*.tar
            rm redpill*.tar
            strip --strip-debug redpill.ko
        fi
    done

    if [ -f /root/redpill.ko ] && [ -n $(strings /root/redpill.ko | grep -i $model | head -1) ]; then
        echo "Copying redpill.ko module to ramdisk"
        cp /root/redpill.ko /root/rd.temp/usr/lib/modules/rp.ko
    else
        echo "Module does not contain platform information for ${model}"
    fi

    [ -f /root/rd.temp/usr/lib/modules/rp.ko ] && echo "Redpill module is in place"

}

function _set_conf_kv() {
    # Delete
    if [ -z "$2" ]; then
        sed -i "$3" -e "s/^$1=.*$//"
        return 0
    fi

    # Replace
    if grep -q "^$1=" "$3"; then
        sed -i "$3" -e "s\"^$1=.*\"$1=\\\"$2\\\"\""
        return 0
    fi

    # Add if doesn't exist
    echo "$1=\"$2\"" >>$3
}

function patchkernel() {

    echo "Patching Kernel"

    /root/tools/bzImage-to-vmlinux.sh /mnt/tcrp-p2/zImage /root/vmlinux >log 2>&1 >/dev/null
    /root/tools/kpatch /root/vmlinux /root/vmlinux-mod >log 2>&1 >/dev/null
    /root/tools/vmlinux-to-bzImage.sh /root/vmlinux-mod /mnt/tcrp/zImage-dsm >/dev/null

    [ -f /mnt/tcrp/zImage-dsm ] && echo "Kernel Patched, sha256sum : $(sha256sum /mnt/tcrp/zImage-dsm | awk '{print $1}')"

}

function extractramdisk() {

    temprd="/root/rd.temp/"

    echo "Extracting ramdisk to $temprd"

    [ ! -d $temprd ] && mkdir $temprd
    cd $temprd

    if [ $(od /mnt/tcrp-p2/rd.gz | head -1 | awk '{print $2}') == "000135" ]; then
        echo "Ramdisk is compressed"
        xz -dc /mnt/tcrp-p2/rd.gz 2>/dev/null | cpio -idm >/dev/null 2>&1
    else
        sudo cat /mnt/tcrp-p2/rd.gz | cpio -idm 2>&1 >/dev/null
    fi

    if [ -f $temprd/etc/VERSION ]; then
        . $temprd/etc/VERSION
        echo "Extracted ramdisk VERSION : ${major}.${minor}.${micro}-${buildnumber}"
    else
        echo "ERROR, Couldnt read extracted file version"
        exit 99
    fi

    version="${major}.${minor}.${micro}-${buildnumber}"
    smallfixnumber="${smallfixnumber}"

}

function patchramdisk() {

    if [ ! -n "$IP" ]; then
        msgalert "The patch cannot proceed because there is no IP yet !!!! \n"
        exit 99
    fi

    extractramdisk

    temprd="/root/rd.temp"
    RAMDISK_PATCH=$(cat /root/config/$model/$version/config.json | jq -r -e ' .patches .ramdisk')
    SYNOINFO_PATCH=$(cat /root/config/$model/$version/config.json | jq -r -e ' .synoinfo')
    SYNOINFO_USER=$(cat /mnt/tcrp/user_config.json | jq -r -e ' .synoinfo')
    RAMDISK_COPY=$(cat /root/config/$model/$version/config.json | jq -r -e ' .extra .ramdisk_copy')
    RD_COMPRESSED=$(cat /root/config/$model/$version/config.json | jq -r -e ' .extra .compress_rd')
    echo "Patching RamDisk"

    PATCHES="$(echo $RAMDISK_PATCH | jq . | sed -e 's/@@@COMMON@@@/\/root\/config\/_common/' | grep config | sed -e 's/"//g' | sed -e 's/,//g')"

    echo "Patches to be applied : $PATCHES"

    cd $temprd
    . $temprd/etc/VERSION
    for patch in $PATCHES; do
        echo "Applying patch $patch in dir $PWD"
        patch -p1 <$patch
    done

    # Patch /sbin/init.post
    grep -v -e '^[\t ]*#' -e '^$' "/root/patch/config-manipulators.sh" >"/root/rp.txt"
    sed -e "/@@@CONFIG-MANIPULATORS-TOOLS@@@/ {" -e "r /root/rp.txt" -e 'd' -e '}' -i "${temprd}/sbin/init.post"
    rm "/root/rp.txt"

    touch "/root/rp.txt"

    echo "Applying model synoinfo patches"

    while IFS=":" read KEY VALUE; do
        if [ -z "$VALUE" ]; then
            continue
        fi
        KEY="$(echo $KEY | xargs)" && VALUE="$(echo $VALUE | xargs)"
        _set_conf_kv "${KEY}" "${VALUE}" $temprd/etc/synoinfo.conf
        echo "_set_conf_kv \"${KEY}\" \"${VALUE}\" /tmpRoot/etc/synoinfo.conf" >>"/root/rp.txt"
        echo "_set_conf_kv \"${KEY}\" \"${VALUE}\" /tmpRoot/etc.defaults/synoinfo.conf" >>"/root/rp.txt"
    done <<<$(echo $SYNOINFO_PATCH | jq . | grep ":" | sed -e 's/"//g' | sed -e 's/,//g')

    echo "Applying user synoinfo settings"

    while IFS=":" read KEY VALUE; do
        if [ -z "$VALUE" ]; then
            continue
        fi
        KEY="$(echo $KEY | xargs)" && VALUE="$(echo $VALUE | xargs)"
        _set_conf_kv "${KEY}" "${VALUE}" $temprd/etc/synoinfo.conf
        echo "_set_conf_kv \"${KEY}\" \"${VALUE}\" /tmpRoot/etc/synoinfo.conf" >>"/root/rp.txt"
        echo "_set_conf_kv \"${KEY}\" \"${VALUE}\" /tmpRoot/etc.defaults/synoinfo.conf" >>"/root/rp.txt"
    done <<<$(echo $SYNOINFO_USER | jq . | grep ":" | sed -e 's/"//g' | sed -e 's/,//g')

    sed -e "/@@@CONFIG-GENERATED@@@/ {" -e "r /root/rp.txt" -e 'd' -e '}' -i "${temprd}/sbin/init.post"
    rm /root/rp.txt

    echo "Copying extra ramdisk files "

    while IFS=":" read SRC DST; do
        echo "Source :$SRC Destination : $DST"
        cp -f $SRC $DST
    done <<<$(echo $RAMDISK_COPY | jq . | grep "COMMON" | sed -e 's/"//g' | sed -e 's/,//g' | sed -e 's/@@@COMMON@@@/\/root\/config\/_common/')

    echo "Adding precompiled redpill module"
    getredpillko
    #getstaticmodule

    echo "Adding custom.gz to image"
    cd $temprd
    if [ -f /mnt/tcrp/custom.gz ]; then
        cat /mnt/tcrp/custom.gz | cpio -idm >/dev/null 2>&1
    else
        cat /mnt/tcrp-p1/custom.gz | cpio -idm >/dev/null 2>&1
    fi

    for script in $(find /root/rd.temp/exts/ | grep ".sh"); do chmod +x $script; done
    chmod +x $temprd/usr/sbin/modprobe

    # Reassembly ramdisk
    echo "Reassempling ramdisk"
    if [ "${RD_COMPRESSED}" == "true" ]; then
        (cd "${temprd}" && find . | cpio -o -H newc -R root:root | xz -9 --format=lzma >"/root/initrd-dsm") >/dev/null 2>&1 >/dev/null
    else
        (cd "${temprd}" && find . | cpio -o -H newc -R root:root >"/root/initrd-dsm") >/dev/null 2>&1
    fi
    [ -f /root/initrd-dsm ] && echo "Patched ramdisk created $(ls -l /root/initrd-dsm)"

    echo "Copying file to ${LOADER_DISK}3"

    cp -f /root/initrd-dsm /mnt/tcrp

    cd /root && rm -rf $temprd

    origrdhash=$(sha256sum /mnt/tcrp-p2/rd.gz | awk '{print $1}')
    origzimghash=$(sha256sum /mnt/tcrp-p2/zImage | awk '{print $1}')
    version="${major}.${minor}.${micro}-${buildnumber}"
    smallfixnumber="${smallfixnumber}"

    updateuserconfigfield "general" "rdhash" "$origrdhash"
    updateuserconfigfield "general" "zimghash" "$origzimghash"
    updateuserconfigfield "general" "version" "${major}.${minor}.${micro}-${buildnumber}"
    updateuserconfigfield "general" "smallfixnumber" "${smallfixnumber}"
    updategrubconf

}

function rebuildloader() {

    losetup -fP /mnt/tcrp/loader72.img
    loopdev=$(losetup -a /mnt/tcrp/loader72.img | awk '{print $1}' | sed -e 's/://')

    if [ -d /root/part1 ]; then
        mount ${loopdev}p1 /root/part1
    else
        mkdir -p /root/part1
        mount ${loopdev}p1 /root/part1
    fi

    if [ -d /root/part2 ]; then
        mount ${loopdev}p2 /root/part2
    else
        mkdir -p /root/part2
        mount ${loopdev}p2 /root/part2
    fi

    localdiskp1="/mnt/tcrp-p1"
    localdiskp2="/mnt/tcrp-p2"

    if [ $(mount | grep -i part1 | wc -l) -eq 1 ] && [ $(mount | grep -i part2 | wc -l) -eq 1 ] && [ $(mount | grep -i ${localdiskp1} | wc -l) -eq 1 ] && [ $(mount | grep -i ${localdiskp2} | wc -l) -eq 1 ]; then
        rm -rf ${localdiskp1}/*
        cp -rf part1/* ${localdiskp1}/
        rm -rf ${localdiskp2}/*
        cp -rf part2/* ${localdiskp2}/
    else
        echo "ERROR: Failed to mount correctly all required partitions"
    fi

    cd /root/

    ####

    umount /root/part1
    umount /root/part2
    losetup -d ${loopdev}
    
}

function checkversionup() {
    revision=$(echo "$version" | cut -d "-" -f2)
    DSM_VERSION=$(cat /mnt/tcrp-p1/GRUB_VER | grep DSM_VERSION | cut -d "=" -f2 | sed 's/"//g')
    if [ ${revision} = '64570' ] && [ ${DSM_VERSION} != '64570' ]; then
        if [ -f /mnt/tcrp/loader72.img ] && [ -f /mnt/tcrp/grub72.cfg ] && [ -f /mnt/tcrp/initrd-dsm72 ]; then
            rebuildloader
            #patchkernel
            #patchramdisk

            echo "copy 7.2 initrd-dsm & grub.cfg"
            cp -vf /mnt/tcrp/grub72.cfg /mnt/tcrp-p1/boot/grub/grub.cfg
            cp -vf /mnt/tcrp/initrd-dsm72 /mnt/tcrp/initrd-dsm
        else
            msgnormal "/mnt/tcrp/loader72.img or /mnt/tcrp/grub72.cfg or /mnt/tcrp/initrd-dsm72 file missing, stop loader full build, please rebuild the loader ..."
            # Check ip upgrade is required
            #checkupgrade
        fi
    else
        msgnormal "Since the revision update was not detected, proceed to the next step. ..."
        # Check ip upgrade is required
        #checkupgrade
    fi
}

function setgrubdefault() {

    echo "Setting default boot entry to $1"
    sed -i "s/set default=\"[0-9]\"/set default=\"$1\"/g" /mnt/tcrp-p1/boot/grub/grub.cfg
}

function updateuserconfigfile() {

    backupfile="$userconfigfile.$(date +%Y%b%d)"
    jsonfile=$(jq . $userconfigfile)

    if [ "$(echo $jsonfile | jq '.general .usrcfgver')" = "null" ] || [ "$(echo $jsonfile | jq -r -e '.general .usrcfgver')" != "$BOOTVER" ]; then
        echo -n "User config file needs update, updating -> "
        jsonfile=$([ "$(echo $jsonfile | jq '.general .usrcfgver')" = "null" ] || [ "$(echo $jsonfile | jq -r -e '.general .usrcfgver')" != "$BOOTVER" ] && echo $jsonfile | jq ".general |= . + { \"usrcfgver\":\"$BOOTVER\" }" || echo $jsonfile | jq .)
        jsonfile=$([ "$(echo $jsonfile | jq '.general .redpillmake')" = "null" ] && echo $jsonfile | jq '.general |= . + { "redpillmake":"dev" }' || echo $jsonfile | jq .)
        jsonfile=$([ "$(echo $jsonfile | jq '.general .friendautoupd')" = "null" ] && echo $jsonfile | jq '.general |= . + { "friendautoupd":"true" }' || echo $jsonfile | jq .)
        jsonfile=$([ "$(echo $jsonfile | jq '.general .hidesensitive')" = "null" ] && echo $jsonfile | jq '.general |= . + { "hidesensitive":"false" }' || echo $jsonfile | jq .)
        jsonfile=$([ "$(echo $jsonfile | jq '.ipsettings')" = "null" ] && echo $jsonfile | jq '. |= .  + {"ipsettings": { "ipset":"", "ipaddr":"", "ipgw":"", "ipdns":"", "ipproxy":"" }}' || echo $jsonfile | jq .)
        cp $userconfigfile $backupfile
        echo $jsonfile | jq . >$userconfigfile && echo "Done" || echo "Failed"

    fi

}

function updategrubconf() {

    curgrubver="$(grep menuentry /mnt/tcrp-p1/boot/grub/grub.cfg | grep RedPill | head -1 | awk '{print $4}')"
    echo "Updating grub version values from: $curgrubver to $version"
    sed -i "s/$curgrubver/$version/g" /mnt/tcrp-p1/boot/grub/grub.cfg

}

function updateuserconfigfield() {

    block="$1"
    field="$2"
    value="$3"

    if [ -n "$1 " ] && [ -n "$2" ]; then
        jsonfile=$(jq ".$block+={\"$field\":\"$value\"}" $userconfigfile)
        echo $jsonfile | jq . >$userconfigfile
    else
        echo "No values to update specified"
    fi
}

function countdown() {
    local timeout=7
    while [ $timeout -ge 0 ]; do
        sleep 1
        printf '\e[32m%s\e[0m\r' "Press <ctrl-c> to stop boot $1 in : $timeout"
        read -t 1 -n 1 key
        case $key in
            #'g') # j key
            #    echo "g key pressed! Prepare Entering Getty Console!"
            #    sleep 3
            #    initialize
            #    boot gettycon
            #    ;;
            'r') # r key
                echo "r key pressed! Entering Menu for Reset DSM Password!"
                pip install passlib >/dev/null 2>/dev/null
                sleep 3
                mainmenu
                ;;
            'e') # e key
                echo "e key pressed! Entering Menu for Edit USB/SATA Command Line!"
                pip install passlib >/dev/null 2>/dev/null                
                sleep 3
                mainmenu
                ;;
            'j') # j key
                echo "j key pressed! Prepare Entering Force Junior!"
                sleep 3
                initialize
                boot forcejunior
                ;;
            *)
                ;;
        esac
        let timeout=$timeout-1
    done
}

function gethw() {

    checkmachine

    echo -ne "Loader BUS: $(msgnormal "$LOADER_BUS\n")"
    echo -ne "Running on $(cat /proc/cpuinfo | grep "model name" | awk -F: '{print $2}' | wc -l) Processor $(cat /proc/cpuinfo | grep "model name" | awk -F: '{print $2}' | uniq) With $(free -h | grep Mem | awk '{print $2}') Memory\n"
    echo -ne "System has $(lspci -nn | egrep -e "\[0104\]" -e "\[0107\]" | wc -l) SAS/RAID HBAs and $(lspci -nn | egrep -e "\[0200\]" | wc -l) Network cards\n"
    [ -d /sys/firmware/efi ] && msgnormal "System is running in UEFI boot mode\n" && EFIMODE="yes" || msgnormal "System is running in Legacy boot mode\n"    
}

function checkmachine() {

    if grep -q ^flags.*\ hypervisor\  /proc/cpuinfo; then
        MACHINE="VIRTUAL"
        HYPERVISOR=$(lscpu | grep "Hypervisor vendor" | awk '{print $3}')
        echo "Machine is $MACHINE and the Hypervisor is $HYPERVISOR"
    else
        MACHINE="BAREMETAL"    
    fi

}

function getusb() {

    # Get the VID/PID if we are in USB
    VID="0x0000"
    PID="0x0000"
    BUS=$(udevadm info --query property --name ${LOADER_DISK} | grep BUS | cut -d= -f2)
    if [ "${BUS}" = "usb" ]; then
        VID="0x$(udevadm info --query property --name ${LOADER_DISK} | grep ID_VENDOR_ID | cut -d= -f2)"
        PID="0x$(udevadm info --query property --name ${LOADER_DISK} | grep ID_MODEL_ID | cut -d= -f2)"
        updateuserconfigfield "extra_cmdline" "pid" "$PID"
        updateuserconfigfield "extra_cmdline" "vid" "$VID"
        curpid=$(jq -r -e .general.usb_line $userconfigfile | awk -Fpid= '{print $2}' | awk '{print  $1}')
        curvid=$(jq -r -e .general.usb_line $userconfigfile | awk -Fvid= '{print $2}' | awk '{print  $1}')
        sed -i "s/${curpid}/${PID}/" $userconfigfile
        sed -i "s/${curvid}/${VID}/" $userconfigfile
    elif [ "${BUS}" != "ata" ]; then
        echo "Loader disk neither USB or DoM"
    fi

}

function getip() {

    ethdevs=$(ls /sys/class/net/ | grep -v lo || true)

    # Wait for an IP
    for eth in $ethdevs; do 
        COUNT=0
        DRIVER=$(ls -ld /sys/class/net/${eth}/device/driver 2>/dev/null | awk -F '/' '{print $NF}')
        msgalert "IP Detecting on ${eth} (${DRIVER}) "    
        while true; do
            if [ ${COUNT} -eq 10 ]; then
                msgalert ", ERROR Could not get IP\n"
                IP=""
                break
            fi
            COUNT=$((${COUNT} + 1))
            IP="$(ip route get 1.1.1.1 2>/dev/null | grep ${eth} | awk '{print $7}')"
            if [ -n "$IP" ]; then
                msgalert "\n"
                echo "IP Address : $(msgnormal "${IP}"), Module Processing Method : $(msgnormal "${dmpm}")"                
                break
            fi
            sleep 1
            msgalert "."
        done
        if [ -n "$IP" ]; then
            break
        fi
    done
}

function checkfiles() {

    files="user_config.json initrd-dsm zImage-dsm"

    for file in $files; do
        if [ -f /mnt/tcrp/$file ]; then
            msgnormal "File : $file OK !"
        else
            msgnormal "File : $file missing  !"
            exit 99
        fi

    done

}

function checkupgrade() {

    origrdhash=$(sha256sum /mnt/tcrp-p2/rd.gz | awk '{print $1}')
    origzimghash=$(sha256sum /mnt/tcrp-p2/zImage | awk '{print $1}')
    rdhash="$(jq -r -e '.general .rdhash' $userconfigfile)"
    zimghash="$(jq -r -e '.general .zimghash' $userconfigfile)"

    if [ "$loadermode" == "JOT" ]; then    
        checkmachine

        if [ "$MACHINE" = "VIRTUAL" ]; then
            msgnormal "Setting default boot entry to JOT SATA\n"
            sed -i "/set default=\"*\"/cset default=\"1\"" /mnt/tcrp-p1/boot/grub/grub.cfg
        else
            msgnormal "Setting default boot entry to JOT USB\n"
            sed -i "/set default=\"*\"/cset default=\"0\"" /mnt/tcrp-p1/boot/grub/grub.cfg
        fi        
    fi

    echo -n "Detecting upgrade : "

    if [ "$rdhash" = "$origrdhash" ]; then
        msgnormal "Ramdisk OK ! "
    else
        msgwarning "Ramdisk upgrade has been detected and "
        if [ ! -n "$IP" ]; then
           getip
        fi
        if [ -n "$IP" ]; then
            patchramdisk 2>&1 >>$FRIENDLOG
        else
            msgalert "The patch cannot proceed because there is no IP yet !!!! \n"
            exit 99
        fi
    fi

    if [ "$zimghash" = "$origzimghash" ]; then
        msgnormal "zImage OK ! \n"
    else
        msgwarning "zImage upgrade has been detected \n"
        patchkernel 2>&1 >>$FRIENDLOG
   
        if [ "$loadermode" == "JOT" ]; then
            msgwarning "Ramdisk upgrade and zImage upgrade for JOT completed successfully !!! \n"
            echo "A reboot is required. Press any key to reboot..."
            read answer
            reboot
        fi
    fi
    
}

function setmac() {

    # Set custom MAC if defined
    ethdevs=$(ls /sys/class/net/ | grep -v lo || true)
    I=1
    for eth in $ethdevs; do 
        curmacmask=$(ip link | grep -A 1 ${eth} | tail -1 | awk '{print $2}' | tr '[:lower:]' '[:upper:]')
        eval "usrmac=\${mac${I}}"
        MAC="${usrmac:0:2}:${usrmac:2:2}:${usrmac:4:2}:${usrmac:6:2}:${usrmac:8:2}:${usrmac:10:2}"
        DRIVER=$(ls -ld /sys/class/net/${eth}/device/driver 2>/dev/null | awk -F '/' '{print $NF}')
        if [ "${usrmac}" != "null" ]; then
            msgnormal "Setting MAC Address from ${curmacmask} to ${MAC} on ${eth} (${DRIVER})\n" | tee -a boot.log
            ip link set dev ${eth} address ${MAC} >/dev/null 2>&1 
        fi
        I=$((${I} + 1))
        if [ "${eth}" = "eth4" ]; then
            break
        fi
    done
    /etc/init.d/S41dhcpcd restart >/dev/null 2>&1
}

function setnetwork() {

    ethdev=$(ip a | grep UP | grep -v LOOP | head -1 | awk '{print $2}' | sed -e 's/://g')

    echo "Network settings are set to static proceeding setting static IP settings" | tee -a boot.log
    staticip="$(jq -r -e .ipsettings.ipaddr /mnt/tcrp/user_config.json)"
    staticdns="$(jq -r -e .ipsettings.ipdns /mnt/tcrp/user_config.json)"
    staticgw="$(jq -r -e .ipsettings.ipgw /mnt/tcrp/user_config.json)"
    staticproxy="$(jq -r -e .ipsettings.ipproxy /mnt/tcrp/user_config.json)"

    [ -n "$staticip" ] && [ $(ip a | grep $staticip | wc -l) -eq 0 ] && ip a add "$staticip" dev $ethdev | tee -a boot.log
    [ -n "$staticdns" ] && [ $(grep ${staticdns} /etc/resolv.conf | wc -l) -eq 0 ] && sed -i "a nameserver $staticdns" /etc/resolv.conf | tee -a boot.log
    [ -n "$staticgw" ] && [ $(ip route | grep "default via ${staticgw}" | wc -l) -eq 0 ] && ip route add default via $staticgw dev $ethdev | tee -a boot.log
    [ -n "$staticproxy" ] &&
        export HTTP_PROXY="$staticproxy" && export HTTPS_PROXY="$staticproxy" &&
        export http_proxy="$staticproxy" && export https_proxy="$staticproxy" | tee -a boot.log

    IP="$(ip route get 1.1.1.1 2>/dev/null | grep $ethdev | awk '{print $7}')"

}

function readconfig() {

    LOADER_DISK=$(blkid | grep "6234-C863" | cut -c 1-8 | awk -F\/ '{print $3}')
    LOADER_BUS="$(udevadm info --query property --name /dev/${LOADER_DISK} | grep -i ID_BUS | awk -F= '{print $2}')"

    userconfigfile=/mnt/tcrp/user_config.json

    if [ -f $userconfigfile ]; then
        model="$(jq -r -e '.general .model' $userconfigfile)"
        version="$(jq -r -e '.general .version' $userconfigfile)"
        smallfixnumber="$(jq -r -e '.general .smallfixnumber' $userconfigfile)"
        redpillmake="$(jq -r -e '.general .redpillmake' $userconfigfile)"
        friendautoupd="$(jq -r -e '.general .friendautoupd' $userconfigfile)"
        hidesensitive="$(jq -r -e '.general .hidesensitive' $userconfigfile)"
        serial="$(jq -r -e '.extra_cmdline .sn' $userconfigfile)"
        rdhash="$(jq -r -e '.general .rdhash' $userconfigfile)"
        zimghash="$(jq -r -e '.general .zimghash' $userconfigfile)"
        mac1="$(jq -r -e '.extra_cmdline .mac1' $userconfigfile)"
        mac2="$(jq -r -e '.extra_cmdline .mac2' $userconfigfile)"
        mac3="$(jq -r -e '.extra_cmdline .mac3' $userconfigfile)"
        mac4="$(jq -r -e '.extra_cmdline .mac4' $userconfigfile)"
        staticboot="$(jq -r -e '.general .staticboot' $userconfigfile)"
        dmpm="$(jq -r -e '.general.devmod' $userconfigfile)"
        loadermode="$(jq -r -e '.general.loadermode' $userconfigfile)"
    else
        echo "ERROR ! User config file : $userconfigfile not found"
    fi

    [ -z "$redpillmake" ] || [ "$redpillmake" = "null" ] && echo "redpillmake setting not found while reading $userconfigfile, defaulting to dev" && redpillmake="dev"

}

function mountall() {

    LOADER_DISK=$(blkid | grep "6234-C863" | cut -c 1-8 | awk -F\/ '{print $3}')

    [ ! -d /mnt/tcrp ] && mkdir /mnt/tcrp
    [ ! -d /mnt/tcrp-p1 ] && mkdir /mnt/tcrp-p1
    [ ! -d /mnt/tcrp-p2 ] && mkdir /mnt/tcrp-p2

    [ "$(mount | grep ${LOADER_DISK}1 | wc -l)" = "0" ] && mount /dev/${LOADER_DISK}1 /mnt/tcrp-p1
    [ "$(mount | grep ${LOADER_DISK}2 | wc -l)" = "0" ] && mount /dev/${LOADER_DISK}2 /mnt/tcrp-p2
    [ "$(mount | grep ${LOADER_DISK}3 | wc -l)" = "0" ] && mount /dev/${LOADER_DISK}3 /mnt/tcrp
    
    if [ "$(mount | grep ${LOADER_DISK}1 | wc -l)" = "0" ]; then
        echo "Failed mount /dev/${LOADER_DISK}1 to /mnt/tcrp-p1, stopping boot process"
        exit 99
    fi

    if [ "$(mount | grep ${LOADER_DISK}2 | wc -l)" = "0" ]; then
        echo "Failed mount /dev${LOADER_DISK}2 to /mnt/tcrp-p2, stopping boot process"
        exit 99
    fi

    if [ "$(mount | grep ${LOADER_DISK}3 | wc -l)" = "0" ]; then
        echo "Failed mount /dev${LOADER_DISK}3 to /mnt/tcrp, stopping boot process"
        exit 99
    fi

}

function boot() {

    # Welcome message
    welcome

    # user_config.json ipsettings block
    # user_config.json ipsettings block

    #  "ipsettings" : {
    #     "ipset": "static",
    #     "ipaddr":"192.168.71.146/24",
    #     "ipgw" : "192.168.71.1",
    #     "ipdns": "",
    #     "ipproxy" : ""
    # },

    if [ "$(jq -r -e .ipsettings.ipset /mnt/tcrp/user_config.json)" = "static" ]; then

        setnetwork
        getip
    else
        # Set Mac Address according to user_config
        setmac

        # Get IP Address after setting new mac address to display IP
        getip
    fi

    # Check whether the major version has been updated from under 7.2 to 7.2
    #checkversionup

    if [ ! -n "$IP" ]; then
        getip
    fi
    # Check ip upgrade is required
    checkupgrade

    # Get USB list and set VID-PID Automatically
    getusb

    # check if new TCRP Friend version is available to download
    if [ ! -n "$IP" ]; then
        getip
    fi
    checkinternet

    [ "${INTERNET}" = "ON" ] && upgradefriend

    if [ -f /mnt/tcrp/stopatfriend ]; then
        echo "Stop at friend detected, stopping boot"
        rm -f /mnt/tcrp/stopatfriend
        touch /root/stoppedatrequest
        exit 0
    fi

    if grep -q "debugfriend" /proc/cmdline; then
        echo "Debug Friend set, stopping boot process"
        exit 0
    fi

    if [ "$LOADER_BUS" = "ata" ]; then

        CMDLINE_LINE=$(jq -r -e '.general .sata_line' /mnt/tcrp/user_config.json)
        # Check dom size and set max size accordingly
        CMDLINE_LINE+=" dom_szmax=$(fdisk -l /dev/${LOADER_DISK} | head -1 | awk -F: '{print $2}' | awk '{ print $1*1024}') "

    else
        CMDLINE_LINE=$(jq -r -e '.general .usb_line' /mnt/tcrp/user_config.json)
    fi

    #[ "$1" = "gettycon" ] && CMDLINE_LINE+=" gettycon "

    [ "$1" = "forcejunior" ] && CMDLINE_LINE+=" force_junior "

    export MOD_ZIMAGE_FILE="/mnt/tcrp/zImage-dsm"
    export MOD_RDGZ_FILE="/mnt/tcrp/initrd-dsm"

    gethw

    echo
    echo -n "Model : $(msgnormal "$model"), Serial : $(msgnormal "$serial"), Mac : $(msgnormal "$mac1"), DSM Version : $(msgnormal "$version"), Update : $(msgnormal "$smallfixnumber"), RedPillMake : $(msgnormal "${redpillmake}\n")"
    echo
    echo "zImage : ${MOD_ZIMAGE_FILE} initrd : ${MOD_RDGZ_FILE}"
    echo
    echo "cmdline : ${CMDLINE_LINE}"
    echo
    echo "Access $(msgalert "http://${IP}:7681") via the TTYD web terminal to check the problem."
    echo "(If you have any problems with the DSM installation steps, check the $(msgwarning "/var/log/linuxrc.syno.log") file in this access)"
    echo "Default TTYD root password is $(msgwarning "blank")"
    echo        
    echo "User config is on $(msgwarning "/mnt/tcrp/user_config.json\n")"
    #if [ "$1" != "gettycon" ] && [ "$1" != "forcejunior" ]; then    
    if [ "$1" != "forcejunior" ]; then    
 #       echo "$(msgalert "Press <g> to enter a Getty Console to solve trouble\n")"
        echo "$(msgalert   "Press <r> to enter a menu for Reset DSM Password\n")" 
        echo "$(msgnormal  "Press <e> to enter a menu for Edit USB/SATA Command Line\n")"
        echo "$(msgwarning "Press <j> to enter a Junior mode\n")"
#    elif [ "$1" = "gettycon" ]; then
#        echo "$(msgalert "Entering a Getty Console to solve trouble...\n")"
    elif [ "$1" = "forcejunior" ]; then
        echo "$(msgwarning "Entering a Junior mode...\n")"        
    fi
    
    # Check netif_num matches the number of configured mac addresses as if these does not match redpill will cause a KP
    echo ${CMDLINE_LINE} >/tmp/cmdline.out
    while IFS=" " read -r -a line; do
        printf "%s\n" "${line[@]}"
    done </tmp/cmdline.out | egrep -i "sn|pid|vid|mac|hddhotplug|netif_num" | sort >/tmp/cmdline.check

    . /tmp/cmdline.check

    [ $(grep mac /tmp/cmdline.check | wc -l) != $netif_num ] && msgalert "FAILED to match the count of configured netif_num and mac addresses, DSM will panic, exiting so you can fix this\n" && exit 99

    #If EFI then add withefi to CMDLINE_LINE
    if [ "$EFIMODE" = "yes" ] && [ $(echo ${CMDLINE_LINE} | grep withefi | wc -l) -le 0 ]; then
        CMDLINE_LINE+=" withefi " && msgwarning "EFI booted system with no EFI option, adding withefi to cmdline\n"
    fi

    if [ "${INTERNET}" = "ON" ]; then
        pip install click >/dev/null 2>/dev/null
        pip install qrcode >/dev/null 2>/dev/null
        pip install Image >/dev/null 2>/dev/null
    fi   

    if [ "$staticboot" = "true" ]; then
        echo "Static boot set, rebooting to static ..."
        cp tools/libdevmapper.so.1.02 /usr/lib
        cp tools/grub-editenv /usr/bin
        chmod +x /usr/bin/grub-editenv
        /usr/bin/grub-editenv /mnt/tcrp-p1/boot/grub/grubenv create        
        [ "$LOADER_BUS" = "ata" ] && setgrubdefault 1
        [ "$LOADER_BUS" = "usb" ] && setgrubdefault 0
        reboot
    else

        #if [ "$1" != "gettycon" ] && [ "$1" != "forcejunior" ]; then
        if [ "$1" != "forcejunior" ]; then
            countdown "booting"
        fi
        echo "Boot timeout exceeded, booting ... "
        echo
        echo "\"HTTP, Synology Web Assistant (BusyBox httpd)\" service may $(msgnormal "take 20 - 40 seconds")."
        echo "(Network access is not immediately available)"
        echo    
        echo "Kernel loading has started, nothing will be displayed here anymore ..."

        if [ "${INTERNET}" = "ON" ]; then
            [ -n "${IP}" ] && URL="http://${IP}:5000" || URL="http://find.synology.com/"
            python functions.py makeqr -d "${URL}" -l "br" -o "/tmp/qrcode.png"
            #curl -skL https://quickchart.io/qr?text="${URL}" -o /tmp/qrcode.png
            [ -f "/tmp/qrcode.png" ] && echo | fbv -acufi "/tmp/qrcode.png" >/dev/null 2>/dev/null || true
        fi    
        
        [ "${hidesensitive}" = "true" ] && clear

        if [ $(echo ${CMDLINE_LINE} | grep withefi | wc -l) -eq 1 ]; then
            kexec -l "${MOD_ZIMAGE_FILE}" --initrd "${MOD_RDGZ_FILE}" --command-line="${CMDLINE_LINE}"
        else
            msgwarning "Booting with noefi, please notice that this might cause issues"
            kexec --noefi -l "${MOD_ZIMAGE_FILE}" --initrd "${MOD_RDGZ_FILE}" --command-line="${CMDLINE_LINE}"
        fi

        kexec -e -a
    fi
}

function welcome() {

    clear
    echo -en "\033[7;32m--------------------------------------={ TinyCore RedPill Friend }=--------------------------------------\033[0m\n"

    # Echo Version
    echo "TCRP Friend Version : $BOOTVER"
    showlastupdate
}

function initialize() {
    # Checkif running in TC
    [ "$(hostname)" != "tcrpfriend" ] && echo "ERROR running on alien system" && exit 99

    # Mount loader disk
    mountall

    # Read Configuration variables
    readconfig

    # No network devices
    eths=$(ls /sys/class/net/ | grep -v lo || true)    
    [ $(echo ${eths} | wc -w) -le 0 ] && echo "No NIC found! - Loader does not work without Network connection." && exit 99

    # Update user config file to latest version
    updateuserconfigfile

    [ "${smallfixnumber}" = "null" ] && patchramdisk 2>&1 >>$FRIENDLOG

}

case $1 in

update)
    getip
    upgradefriend
    ;;

patchramdisk)
    initialize
    patchramdisk
    ;;

patchkernel)
    initialize
    patchkernel
    ;;

rebuildloader)
    initialize
    rebuildloader
    cp -vf /mnt/tcrp/grub72.cfg /mnt/tcrp-p1/boot/grub/grub.cfg
    cp -vf /mnt/tcrp/initrd-dsm72 /mnt/tcrp/initrd-dsm    
    #patchkernel
    #patchramdisk
    ;;

version)
    version $@
    ;;

extractramdisk)
    initialize
    extractramdisk
    ;;

forcejunior)
    initialize
    boot forcejunior
    ;;

#gettycon)
#    initialize
#    boot gettycon
#    ;;

menu)
    mainmenu
    initialize
    boot
    ;;

*)
    initialize
    # All done, lets go for boot/
    boot
    ;;

esac
