
# HLS_COMPONENT=custom_hls_vdotprod
# HLS_COMPONENT=custom_hls_gemm_v1_0
HLS_COMPONENT=custom_hls_gemm_v1_1

# HLS_COMPONENTS=('custom_hls_conv_naive' 'custom_hls_conv_opt1' 'custom_hls_conv_opt2' 'custom_hls_conv_opt3' 'custom_hls_conv_opt4' 'custom_hls_conv_opt5' 'custom_hls_conv_opt6')

HLS_COMPONENTS=('custom_hls_conv_opt6')

for component in "${HLS_COMPONENTS[@]}"
do
    # Clean generated sources
    make -C hw/units/ clean_$component
    # Rebuild
    source hw/units/$component/assets/rebuild_hls.sh

    # Clean IP
    make -C hw/xilinx/ clean_ips/$component.xci
    # Rebuild IP
    make -C hw/xilinx/ ips/$component.xci
done

# Rebuild whole bitstream
# NOTE: Keep -j in case config has been updated
# make -C hw/xilinx/ clean bitstream -j 8
