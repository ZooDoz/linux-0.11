 ;/*
 ; *  head.s contains the 32-bit startup code.
 ; *
 ; * NOTE!!! Startup happens at absolute address 0x00000000, which is also where
 ; * the page directory will exist. The startup code will be overwritten by
 ; * the page directory.
 ; */
