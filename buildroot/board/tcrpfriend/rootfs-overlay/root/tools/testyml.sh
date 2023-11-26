      pataddress="https://global.download.synology.com/download/DSM/release/7.2/64561/DSM_SA6400_64561.pat"
      toolchain="https://global.download.synology.com/download/ToolChain/toolchain/7.1-42661/AMD%20x86%20Linux%20Linux%205.10.55%20%28epyc7002%29/epyc7002-gcc850_glibc226_x86_64-GPL.txz"
      linuxsrc="https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.55.tar.xz"

          patfile=$(basename ${pataddress} | while read; do echo -e ${REPLY//%/\\x}; done)
          echo "::set-output name=patfile::$patfile"
          
          # install bsdiff
          apt-get install -y bsdiff cpio xz-utils
          # install libelf-dev
          apt-get install libelf-dev

          #ls -al $GITHUB_WORKSPACE/
          mkdir /opt/build
          mkdir /opt/dist
          cd /opt/build
          [ ! -f /opt/build/ds.pat ] && curl -kL ${pataddress} -o ds.pat
          [ ! -f /opt/build/toolchain.txz ] && curl -kL ${toolchain} -o toolchain.txz
          [ ! -f /opt/build/linux.tar.xz ] && curl -kL ${linuxsrc} -o linux.tar.xz
          
          # download old pat for syno_extract_system_patch # thanks for jumkey's idea.
          mkdir synoesp
          [ ! -f /opt/build/oldpat.tar.gz ] && curl -kL https://global.download.synology.com/download/DSM/release/7.0.1/42218/DSM_DS3622xs%2B_42218.pat -o oldpat.tar.gz
          tar -C./synoesp/ -xf oldpat.tar.gz rd.gz

          cd synoesp
          xz -dc < rd.gz >rd 2>/dev/null || echo "extract rd.gz"
          echo "finish"
          cpio -idm <rd 2>&1 || echo "extract rd"
          mkdir extract 
          cd extract
          cp ../usr/lib/libcurl.so.4 ../usr/lib/libmbedcrypto.so.5 ../usr/lib/libmbedtls.so.13 ../usr/lib/libmbedx509.so.1 ../usr/lib/libmsgpackc.so.2 ../usr/lib/libsodium.so ../usr/lib/libsynocodesign-ng-virtual-junior-wins.so.7 ../usr/syno/bin/scemd ./
          ln -s scemd syno_extract_system_patch
          cd ../..
          mkdir pat
          #tar xf ds.pat -C pat
          ls -lh ./
          LD_LIBRARY_PATH=synoesp/extract synoesp/extract/syno_extract_system_patch ds.pat pat || echo "extract latest pat"
          echo "test4"
          # is update_pack
          if [ ! -f "pat/zImage" ]; then
            cd pat
            ar x $(ls flashupdate*)
            tar xf data.tar.xz
            cd ..
          fi
          echo "test5"
          mkdir toolchain
          tar xf toolchain.txz -C toolchain
          mkdir linux-src
          tar xf linux.tar.xz --strip-components 1 -C linux-src
          # extract vmlinux
          ./linux-src/scripts/extract-vmlinux pat/zImage > vmlinux
          # sha256
          sha256sum ds.pat >> checksum.sha256
          sha256sum pat/zImage >> checksum.sha256
          sha256sum pat/rd.gz >> checksum.sha256
          sha256sum vmlinux >> checksum.sha256
          cat checksum.sha256
          # patch vmlinux
          # vmlinux_mod.bin
          #curl -L https://github.com/jumkey/dsm-research/raw/master/tools/common.php -o common.php
          #curl -L https://github.com/jumkey/dsm-research/raw/master/tools/patch-ramdisk-check.php -o patch-ramdisk-check.php
          #curl -L https://github.com/jumkey/dsm-research/raw/master/tools/patch-boot_params-check.php -o patch-boot_params-check.php
          #php patch-boot_params-check.php vmlinux vmlinux-mod
          #php patch-ramdisk-check.php vmlinux-mod vmlinux_mod.bin
          # New fabio patching method 
          echo "Patching Kernel"
          curl -kLO https://github.com/PeterSuh-Q3/tinycore-redpill/raw/main/tools/bzImage-to-vmlinux.sh
          curl -kLO https://github.com/PeterSuh-Q3/tinycore-redpill/raw/main/tools/kpatch
          curl -kLO https://github.com/PeterSuh-Q3/tinycore-redpill/raw/main/tools/vmlinux-to-bzImage.sh
          curl -kLO https://github.com/PeterSuh-Q3/tinycore-redpill/raw/main/tools/bzImage-template-v5.gz
          curl -kLO https://github.com/PeterSuh-Q3/tinycore-redpill/raw/main/tools/calc_run_size.sh
           
          chmod 777 kpatch
          chmod 777 calc_run_size.sh
          chmod 777 bzImage-to-vmlinux.sh
          chmod 777 vmlinux-to-bzImage.sh
           
          echo "Current path `pwd`"

          ls -ltr 

          ./kpatch /opt/build/vmlinux /opt/build/vmlinux_mod.bin 
          ./vmlinux-to-bzImage.sh vmlinux-mod bzImage
          ./bzImage-to-vmlinux.sh vmlinux_mod.bin zImage_mod
