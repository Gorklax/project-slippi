################################################################################
#                      Inject at address 8006b0dc
# Function is PlayerThink_ControllerInputsToDataOffset. Injection location
# suggested by Achilles
################################################################################

#replaced code line is executed at the end

################################################################################
#                   subroutine: readInputs
# description: reads inputs from Slippi for a given frame and overwrites
# memory locations
################################################################################
#create stack frame and store link register
mflr r0
stw r0, 0x4(r1)
stwu r1,-0x20(r1)
stw r3,0x1C(r1)
stw r4,0x18(r1)

#------------- INITIALIZE -------------
# here we want to initalize some variables we plan on using throughout
lbz r7, 0xC(r31) #loads this player slot

# generate address for static player block
lis r8, 0x8045
ori r8, r8, 0x3080
mulli r3, r7, 0xE90
add r8, r8, r3

# check if we are playing ice climbers, if we are we need to check if this is nana
lwz r3, 0x4(r8)
cmpwi r3, 0xE
bne+ SKIP_NANA_CHECK

# we need to check if this is a follower (nana). should not load inputs for nana
lwz r3, 0xB4(r8) # load pointer to follower for this port
cmpw r3, r30 # compare follower pointer with current pointer
beq- CLEANUP # if the two match, this is a follower
SKIP_NANA_CHECK:

#------------- START MAIN -------------
bl startExiTransfer

li r3,0x76
bl sendByteExi

#Frame Number
lis r4,0x8048
lwz r4,-0x62A8(r4) # load scene controller frame count
lis r3,0x8047
lwz r3,-0x493C(r3) #load match frame count
cmpwi r3, 0
bne SKIP_FRAME_COUNT_ADJUST #this makes it so that if the timer hasn't started yet, we have a unique frame count still
sub r3,r3,r4
li r4,-0x7B
sub r3,r4,r3
SKIP_FRAME_COUNT_ADJUST:
bl sendWordExi

mr r3, r7 #player slot
bl sendByteExi

REPLAY:
bl readWordExi
#lis r4,0x804D
#stw r3,0x5F90(r4) #RNG seed
bl readWordExi
stw r3,0x620(r31) #analog X
bl readWordExi
stw r3,0x624(r31) #analog Y
bl readWordExi
stw r3,0x638(r31) #cstick X
bl readWordExi
stw r3,0x63C(r31) #cstick Y
bl readWordExi
stw r3,0x650(r31) #trigger
bl readWordExi
stw r3,0x65C(r31) #buttons

bl endExiTransfer

CLEANUP:
#restore registers and sp
lwz r0, 0x24(r1)
lwz r3, 0x1C(r1)
lwz r4, 0x18(r1)
addi r1, r1, 0x20
mtlr r0

b GECKO_END

################################################################################
#                  subroutine: startExiTransfer
#  description: prepares port B exi to be written to
################################################################################
startExiTransfer:
lis r11, 0xCC00 #top bytes of address of EXI registers

#disable read/write protection on memory pages
lhz r10, 0x4010(r11)
ori r10, r10, 0xFF
sth r10, 0x4010(r11) # disable MP3 memory protection

#set up EXI
li r10, 0xB0 #bit pattern to set clock to 8 MHz and enable CS for device 0
stw r10, 0x6814(r11) #start transfer, write to parameter register

blr

################################################################################
#                    subroutine: sendByteExi
#  description: sends one byte over port B exi
#  inputs: r3 byte to send
################################################################################
sendByteExi:
lis r11, 0xCC00 #top bytes of address of EXI registers
li r10, 0x5 #bit pattern to write to control register to write one byte

#write value in r3 to EXI
slwi r3, r3, 24 #the byte to send has to be left shifted
stw r3, 0x6824(r11) #store current byte into transfer register
stw r10, 0x6820(r11) #write to control register to begin transfer

#wait until byte has been transferred
EXI_CHECK_RECEIVE_WAIT:
lwz r10, 0x6820(r11)
andi. r10, r10, 1
bne EXI_CHECK_RECEIVE_WAIT

blr

################################################################################
#                    subroutine: sendWordExi
#  description: sends one word over port B exi
#  inputs: r3 word to send
################################################################################
sendWordExi:
lis r11, 0xCC00 #top bytes of address of EXI registers
li r10, 0x35 #bit pattern to write to control register to write four bytes

#write value in r3 to EXI
stw r3, 0x6824(r11) #store current bytes into transfer register
stw r10, 0x6820(r11) #write to control register to begin transfer

#wait until byte has been transferred
EXI_CHECK_RECEIVE_WAIT_WORD:
lwz r10, 0x6820(r11)
andi. r10, r10, 1
bne EXI_CHECK_RECEIVE_WAIT_WORD

blr

################################################################################
#                    subroutine: readWordExi
#  description: reads one word over port B exi
#  outputs: r3 received word
################################################################################
readWordExi:
lis r11, 0xCC00 #top bytes of address of EXI registers
li r10, 0x31 #bit pattern to write to control register to read four bytes
stw r10, 0x6820(r11) #write to control register to begin transfer

#wait until byte has been transferred
EXI_CHECK_RECEIVE_WAIT_READWORD:
lwz r10, 0x6820(r11)
andi. r10, r10, 1
bne EXI_CHECK_RECEIVE_WAIT_READWORD

#read values from transfer register to r3 for output
lwz r3, 0x6824(r11) #read from transfer register

blr

################################################################################
#                  subroutine: endExiTransfer
#  description: stops port B writes
################################################################################
endExiTransfer:
lis r11, 0xCC00 #top bytes of address of EXI registers

li r10, 0
stw r10, 0x6814(r11) #write 0 to the parameter register

blr

GECKO_END:
lbz r0, 0x2219(r31) #execute replaced code line
