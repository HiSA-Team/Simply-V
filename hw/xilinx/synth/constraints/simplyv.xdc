# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description: Board-independent constraints

# False path though VIO reset
set VIO_RESETN [get_pins -of [get_nets vio_resetn] -filter {NAME=~vio_inst/*}]
set_false_path -hold -through $VIO_RESETN