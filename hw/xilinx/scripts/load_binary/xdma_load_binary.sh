#!/bin/bash
# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description: Load a binary into the SoC memory through the XDMA and PCIe
# This is a bash script in the "tcl" directory ...

EXPECTED_ARGC=4;
ARGC=$#;

# Print the right usage
help (){
    echo  "Usage: source ${BASH_SOURCE[0]} <PCIe BAR> <file_name> <base_address> <read_back>";
    echo  "    PCIe BAR      :  target BAR of PCIe device";
    echo  "    binary_file   :  path to bin file to transfer";
    echo  "    offset        :  offset in SoC";
    echo  "    read_back     :  whether to read-back data after writing";
    return;
}

# Check the argc
if [ $ARGC -ne $EXPECTED_ARGC ];
then
    echo  "Invalid number of arguments, please check the inputs and try again";
    help;
    return 1;
fi

# Get the args
PCIE_BAR=$1
FILE_NAME=$2;
OFFSET=$3;
READBACK=$4;

# Get the file size in bytes
FILE_SIZE=$(stat -c%s "$FILE_NAME");

# Read the entire file in hexadecimal
# We need the -u flag for the devmem-based read-back check
hex_file=$(xxd -p -u -c 9999999999 $FILE_NAME);

# Set the transaction size in bytes
trans_size=8; # Host-side BAR space supports 8-bytes transactions

# Compute number of transactions
num_trans=$(($FILE_SIZE/$trans_size));
remaining_bytes=$(($FILE_SIZE%$trans_size));

# Print warning
if [ $remaining_bytes -ne 0 ]; then
    # Padding size
    pad_size=$(( $trans_size - $remaining_bytes ))
    # Warning message
    echo "[WARINING] Binary has non $trans_size-aligned size ($FILE_SIZE), padding with $pad_size zero-bytes" >&2
    # Pad with zeros
    for((i=0; i<$pad_size; i=i+1));
    do
        hex_file="$hex_file""00"
    done
    # Add one burst
    num_trans=$(($num_trans +1))
fi

# Golden result for later readback check
golden_hex=""

# Write the binary
addr=$(($PCIE_BAR + $OFFSET))
echo "Start writing...";
# For each transaction
for i in $(seq 1 $num_trans);
do
    # Clear accumulator
    hex_data="";

    # Flip endiannes from string (0x01234567 -> 0x67452301)
    # For each byte (2 nibbles) in $trans_size
    for((j=$i*2*$trans_size-2; j>$(($i-1))*2*$trans_size-2; j=j-2));
    do
        # Append a single byte (2 nibbles slice)
        hex_data=${hex_data}${hex_file:$((j)):$((2))}
    done

    # Write to BAR-mapped address
    hex_addr=$(printf "%x" $addr);
    sudo busybox devmem 0x$hex_addr $(($trans_size*8)) 0x$hex_data

    # Increment address
    addr=$(($addr + $trans_size));

    # Save for readback
    if [[ ${READBACK} == "true" ]];
    then
        # Append to old
        golden_hex=${golden_hex}${hex_data}
    fi
done

echo "Write complete!";

# Readback
if [[ ${READBACK} == "true" ]];
then
    echo "Start readback...";
    addr=$(($PCIE_BAR + $OFFSET))
    readback_data="";
    for i in $(seq 0 $(($num_trans-1)));
    do
        hex_addr=$(printf "%x" $addr);
        tmp_data=$( sudo busybox devmem 0x$hex_addr $(($trans_size*8)));
        readback_data=${readback_data}${tmp_data:2:$trans_size*2};         # Slice to remove the 'hex prefix' ( 0x )
        addr=$(($addr+$trans_size));
    done

    echo "Readback complete!";
    echo "Golden hexadecimal binary:";
    echo $golden_hex;
    echo "Readback hexadecimal data:";
    echo $readback_data;

    # Check they are the same
    if [[ ${golden_hex} == ${readback_data} ]];
    then
        echo "Test passed :)";
    else
        echo "Test failed :(";
    fi
fi
