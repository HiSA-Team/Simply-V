# Description: Generate bitsreams for HLS fast prototyping experiments

SOC_CONFIG=hpc

# Setup
source settings.sh ${SOC_CONFIG}

# Target RTL source
TARGET_UNINASOC_RTL=hw/xilinx/rtl/uninasoc.sv

HLS_CONFIGS=(
    # "conv_naive" # First naive version
    "conv_opt1"  # Memory coalescing (AXI bursts)
    "conv_opt2"  # Double buffering
    "conv_opt3"  # Split r/r/w interfaces
    "conv_opt4"  # Frequency scaling
    "conv_opt5"  # Lower bit-widths (ap_int)
    "conv_opt6"  # Wide, single M_AXI for HBUS
)

# Preliminary builds
make config # sw
make units

# For each config
for config in ${HLS_CONFIGS[*]}; do
    # Edit source file
    sed -i -E "s/    localparam string CUSTOM_HLS_VERSION.+/    localparam string CUSTOM_HLS_VERSION = \"$config\";/g" $TARGET_UNINASOC_RTL

    # Enable ILA
    XILINX_ILA=1

    # Change config (if necessary)
    TARGET_CONFIG=config/configs/${SOC_CONFIG}/config_main_bus.csv
    if [[ "$config" == "conv_opt3" ]]; then
        cp -v config/configs/${SOC_CONFIG}/config_main_bus_hls_3intf.csv $TARGET_CONFIG
        # Disable ILA
        XILINX_ILA=0
    elif [[ "$config" == "conv_opt4" ]]; then
        cp -v config/configs/${SOC_CONFIG}/config_main_bus_hls_freq.csv $TARGET_CONFIG
    elif [[ "$config" == "conv_opt6" ]]; then
        cp -v config/configs/${SOC_CONFIG}/config_main_bus_hbus.csv $TARGET_CONFIG
    else
        cp -v config/configs/${SOC_CONFIG}/config_main_bus_base.csv $TARGET_CONFIG
    fi

    # Re-config
    make config
    # Re-build IPs
    make -C hw/xilinx ips -j 8
    # Re-build bitstream
    make -C hw/xilinx clean bitstream XILINX_ILA=$XILINX_ILA

    # Backup bitstream
    BUILD_DIR=hw/xilinx/build
    BACKUP_DIR=hw/xilinx/build_${SOC_CONFIG}_${config}
    cp -r $BUILD_DIR $BACKUP_DIR
    sleep 1
done


echo "[BUILD] Done!"
find hw/xilinx -name uninasoc.bit | grep ${SOC_CONFIG}
