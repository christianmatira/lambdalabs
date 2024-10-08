#!/bin/sh
# From: git@github.com:markwdalton/lambdalabs.git
#
# Has all the Xid errors except 94 or ones for A100
# Add the path you place the CSV list of errors
NVIDIA_XID_ERRORS="./xid-errors.csv"

#1.Avoid the binaries generally and faster:: - DONE
#    Run nvidia-bug-report once through col -b to tmp file
# 2. Get the NVIDIA card model: - DONE
#     grep -A 2 "^[0-9a-z][0-9a-z]:00.0" | grep -A 2 NVIDIA 
# 3. Make sure to add the A100 messages - DONE
# 4. Add the 'undocumented Xids we have seen recently" - new bios for 420GP-TNR - DONE
#    Commonly also GPUs show a 'Unknown Error"
# 5. Get the Baseboard also     - DONE
# 6. Check Segfaults            - DONE
# 7. Check CPU Throttlng        - DONE
# 8. Check for "Hardware Error" - DONE
#
# Other Check's TBD:
#   Quadro 8000 - vBIOS - Original Video BIOS has a fix for failures - Xid - falling off the bus
#   SMC 4124GO-NART/4124GO-NART+ - 'limited by or slow stuck at GPU 500Mhz - BIOS update'
#   Gigabyte G292-Z4* G492-Z5*   - BIOS update for GPU failures, crashes - SERR/PERR in 'ipmitool sel elist'
#

if [ -z "$1" ]; then
  echo "Using nvidia-bug-report.log"
  FILE=nvidia-bug-report.log
else
  FILE=$1
fi

if [ ! -f $FILE ]; then
  echo "File: $FILE not found,"
  exit
fi

cat $FILE | col -b > ${FILE}.orig 
mv ${FILE}.orig ${FILE}

# Summary of GPUs
DATE=$(grep "^Date:" ${FILE})
echo "Log from: $DATE"

NVIDIA_VERSION=$(grep "^Driver Version" ${FILE} | sort | uniq)
CHASSIS=$(grep DMI: ${FILE} | cut -f2 -d":")
CHASSIS2=$(grep -A 4 "^System Information" ${FILE} | egrep "Manufacturer:|Product Name:|Serial Number:" | cut -f2 -d":" | awk '{printf "%s ",$1}')
BASEBOARD=$(grep -A 4 "Base Board Information" ${FILE} | egrep "Product Name:" | cut -f2 -d":")
BIOS=$(grep -A 4 "^BIOS Information" ${FILE} | egrep "Version:|Release Date:" | awk -F":" '{printf "%s ",$2}')
BOOT_LINE=$(egrep -A 1 cmdline ${FILE} | tail -1)
CPUS=$(egrep "^model name" ${FILE} | sort | uniq)
THREADS=$(egrep "^model name" ${FILE} | sort | uniq -c | awk '{print $1}')
echo "Chassis DMI: ${CHASSIS}"
echo "Chassis: ${CHASSIS2}"
echo "BaseBoard info: ${BASEBOARD}"
echo "  BIOS: ${BIOS}"
echo "  CPUs # threads: ${THREADS} of CPU: ${CPUS}"
echo "  BOOT Line: ${BOOT_LINE}"
echo "  Memory:"
echo "      Count     DIMM Information"
grep -B 8 -A 12 DIMM ${FILE} | egrep "Size|Speed|Manufacturer:|Part Number:" | sort | uniq -c | egrep -v "Configured|Logical Size|Non-Volatile|Cache Size" | egrep -v "None|Unknown|NO DIMM|No Module" | sed 's/^/    /g'
echo " "
echo "Summary of PCI Addresses and GPUs"
awk '/^GPU UUID:/ {id=$3 } /^Bus Location:/ { print $3, id }' ${FILE}
echo " "
echo "GPUs:"
egrep "^Model:" ${FILE} | sort | uniq -c
grep -A 2 "^[0-9a-z][0-9a-z]:00.0" ${FILE} | grep -A 2 NVIDIA | grep "Subsystem:" | sort | uniq -c | sed 's/^/    /g'
echo "NVIDIA ${NVIDIA_VERSION}"

echo " "

# Check for Version Conflicts between Driver and Fabric manager
VERSION_CONFLICT=$(egrep "Please update with matching NVIDIA driver" ${FILE} | wc -l)
if [ ${VERSION_CONFLICT} -gt 0 ]; then
    echo " "
    echo "** There are GPU Driver and Fabric Manager Conflicts count:(${VERSION_CONFLICT})"
    echo "     Please run the following to see them:"
    echo "       egrep 'Please update with matching NVIDIA driver' ${FILE}"
    echo "    ** This is important for any SXM chassis **"
    echo "       Check with:"
    echo "        'nvidia-smi topo -m'"
    echo "         python -c \"import torch ; print('Is available: ', torch.cuda.is_available())\""
    echo "         TF_CPP_MIN_LOG_LEVEL=3 python -c \"import tensorflow as tf; print('Num GPUs Available: ', \\"
    echo "            len(tf.config.experimental.list_physical_devices('GPU')))\""
    echo " "
fi

# Check for Xid Errors
XID_COUNT=$(grep "kernel: NVRM: Xid" ${FILE} | cut -f1,5,6,7,8,9,10,11,12 -d: | cut -f1 -d"," | awk '{print $1,$2,$4,$5,$6}' | egrep -v -c "egrep")
if [ ${XID_COUNT} -gt 0 ]; then
   echo " "
   echo "Summary of Xid errors:"
   echo " Definitions: https://docs.nvidia.com/deploy/xid-errors/index.html"
   echo " A100 Xids: https://docs.nvidia.com/deploy/a100-gpu-mem-error-mgmt/index.html"
   echo "            https://docs.nvidia.com/deploy/gpu-debug-guidelines/index.html"
   echo " Fabric errors: https://docs.nvidia.com/datacenter/tesla/pdf/fabric-manager-user-guide.pdf"
   grep "kernel: NVRM: Xid" ${FILE} | cut -f1,5,6,7,8,9,10,11,12 -d: | cut -f1 -d"," | awk '{print $1,$2,$4,$5,$6}' | egrep -v "egrep" | sort | uniq -c
   echo " "
   echo "Summary of error descriptions:"
   XID_ERRORS=$(grep "kernel: NVRM: Xid" ${FILE} | cut -f1 -d"," | awk '{print $9}' | sort | uniq)
   for XID_ERROR in $XID_ERRORS ; do
     grep "^${XID_ERROR}," ${NVIDIA_XID_ERRORS} | sed 's/,/	/g' | sed 's/^/   /g'
   done
else
   echo "No Xid errors found"
fi

# Check for Thermal Slowdown:
THERMAL_SLOW=$(egrep "SW Thermal Slowdown|HW Thermal Slowdown" ${FILE} | grep -c ": Active")
if [ ${THERMAL_SLOW} -gt 0 ]; then
   echo " "
   echo "** Thermal Slow down:"
   egrep "SW Thermal Slowdown|HW Thermal Slowdown" ${FILE} | grep ": Active" | sed '^/   /g'
   echo " "
else 
   echo "No thermal slowdown messages found"
fi

# Check for Segfaults:
SEGFAULTS=$(egrep "segfault" ${FILE} | wc -l)
if [ ${SEGFAULTS} -gt 0 ]; then
   echo " "
   echo "Segfaults: ${SEGFAULTS}"
   egrep "segfault" ${FILE} | sed 's/^/    /g'
   echo " " 
else
   echo "No segfaults found"
fi

CPU_THROTTLE=$(egrep "cpu clock throttled" ${FILE} | wc -l)
if [ ${CPU_THROTTLE} -gt 0 ]; then
   echo " "
   echo "** There was CPU thottling:"
   grep "cpu clock throttled" ${FILE}| cut -f3 -d":" | sort | uniq -c | sed 's/^/     /g'
   echo " "
else
   echo "No CPU throttling"
fi

# Check for Hardware Errors:
HARDWARE_ERRORS=$(grep -c "Hardware Error" ${FILE})
if [ ${HARDWARE_ERRORS} -gt 0 ]; then
   echo " "
   echo "** Hardware Errors: ${HARDWARE_ERRORS}"
   echo "  To find specific errors:"
   echo "      egrep 'Hardware Error' ${FILE}"
   echo " "
else
   echo "No Hardware Errors found"
fi

echo ""
# GPUs fallen off the bus:
FALLEN_ERRORS=$(egrep "kernel: NVRM:.*GPU has fallen off the bus" ${FILE} | wc -l)
if [ ${FALLEN_ERRORS} -gt 0 ]; then
   echo " "
   echo "** Fallen off the bus Errors: ${FALLEN_ERRORS}"
   egrep "kernel: NVRM: GPU at PCI|kernel: NVRM:.*GPU has fallen off the bus" ${FILE} | sed 's/^/   /g'
   echo " "
else
   echo "No 'fallen off the bus' errors"
fi

# Check if GPUs failed init
RMINIT_FAILED=$(egrep "RmInitAdapter failed|rm_init_adapter failed" ${FILE} | wc -l)
if [ ${RMINIT_FAILED} -gt 0 ]; then
   echo " "
   echo "** GPU RmInitiAdapter Failed"
   egrep "RmInitAdapter failed|rm_init_adapter failed" ${FILE} | grep "]" | cut -f2 -d"]" | sort | uniq -c
   echo " "
else
   echo "No 'RmInit failures'"
fi

grep "kernel: nvidia-gpu.*Refused to change power state," ${FILE}

# Check for Bad CPU messages
BAD_CPU=$(egrep "bad cpu" ${FILE} | wc -l)
if [ ${BAD_CPU} -gt 0 ]; then
   echo " "
   echo "bad cpu error found - Commonly due to only 255 of 256+ threads seen"
   echo "Quick fix disable SMT in BIOS - only real threads"
   echo "Real fix depends on Motherboard/BIOS:"
   echo " Here is the step-by-step: for G292-Z40 variance on G492-Z51 (no X2APIC or IOMMU required)"
   echo "   Change the BIOS to enable X2APIC - see below for the place in the manual "
   echo "   Change the BIOS to enable IOMMU - see below for the place in the manual "
   echo "   Change the kernel to add amd_iommu=on: "
   echo "   $ /etc/default/grub: add 'amd_iommu=on' to the line: "
   echo "            GRUB_CMDLINE_LINUX_DEFAULT='root=* quiet splash *' "
   echo "   $ sudo sed -iE '/^GRUB_CMDLINE.*DEFAULT/ s/$/ amd_iommu=on'/' /etc/default/grub "
   echo "   $ sudo update-grub "
   echo "   ... "
   echo "   $ sudo reboot "
   echo "   For the BIOS: "
   echo "   Enabling IOMMU (page 92)  amd X2APIC (Local APIC Mode) page 85  in the BIOS: "
   echo "     https://download.gigabyte.com/FileList/Manual/server_manual_e_G492-Z5x_v10.pdf "
   echo "        From the Manual on 'AMD CPS'"
   echo "        IOMMU Enable/Disable the IOMMU function. Options available: Enabled/Disabled. Default setting is Disabled."
else
   echo "No 'bad cpu' Errors found"
fi

