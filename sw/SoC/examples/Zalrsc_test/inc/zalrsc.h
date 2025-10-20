// Author: Valerio Di Domenico <valerio.didomenico@unina.it>
// Description: Zalrsc tests' functions header file

#ifndef ZALRSC_H
#define ZALRSC_H

#define STEP 0x1000   // Step between test addresses

// LR.W / SC.W function
int lr_w_sc_sequence(volatile unsigned int* addr, unsigned int new_val);

// LR.W.aq / SC.W.rl function
int lr_w_aq_sc_rl_sequence(volatile unsigned int* addr, unsigned int new_val);

// LR.W.aqrl / SC.W.aqrl function
int lr_w_aqrl_sc_aqrl_sequence(volatile unsigned int* addr, unsigned int new_val);


#ifdef __LP64__

// LR.D / SC.D function
int lr_d_sc_sequence(volatile unsigned long long* addr, unsigned long long new_val);

// LR.D.aq / SC.D.rl function
int lr_d_aq_sc_rl_sequence(volatile unsigned long long* addr, unsigned long long new_val);

// LR.D.aqrl / SC.D.aqrl function
int lr_d_aqrl_sc_aqrl_sequence(volatile unsigned long long* addr, unsigned long long new_val);

#endif
#endif