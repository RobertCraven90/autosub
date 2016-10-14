#!/bin/bash

########################################################################
# tester.sh for VHDL task example
# Tests the task submission, creates the error messages
#
# Copyright (C) 2015 Martin  Mosbeck   <martin.mosbeck@gmx.at>
# License GPL V2 or later (see http://www.gnu.org/licenses/gpl2.txt)
########################################################################


##########################
######## RETURNS #########
##########################
# exit 3 something is wrong with test generation
# exit 1 student solution syntax or behavior wrong
# exit 0 student solution right behavior

##########################
####### PARAMETERS #######
##########################
# $1 ... UserId
# $2 ... TaskNr
# $3 ... TaskParameters

##########################
########## PATHS #########
##########################
# src path of autosub system
autosubPath=$(pwd) 
# root path of the task itself
taskPath=$(readlink -f $0|xargs dirname)
# path for all the files that describe the created path
descPath="$autosubPath/users/$1/Task$2/desc"
#path where the testing takes place
userTaskPath="$autosubPath/users/$1/Task$2"

##########################
###### DEFINITIONS #######
##########################
zero=0
userfile="ALU_beh.vhdl"

TaskNr=$2
logPrefix()
{
   logPre=$(date +"%Y-%m-%d %H:%M:%S,%3N ")"[tester.sh Task$TaskNr]   "
}

##########################
#### TEST PREPARATION ####
##########################
cd $taskPath

#generate the testbench and move testbench to user's folder
python3 scripts/generateTestBench.py $3 > $userTaskPath/ALU_tb_$1_Task$2.vhdl 

#copy the entity vhdl file for testing to user's folder
cp $descPath/ALU.vhdl $userTaskPath

# copy the isim tcl file for testing to user's folder
cp $taskPath/scripts/isim.cmd $userTaskPath

#change to userTaskPath, generate space for errors
cd $userTaskPath
touch error_msg

#check if the user supplied a file
if [ ! -f $userfile ]
then
    logPrefix && echo "${logPre}Error with Task $2. User $1 did not attach the right file"
    cd $autosubPath
    echo "You did not attach your solution. Please attach the file $userfile" >$userTaskPath/error_msg
    exit 1 
fi

# create tmp directory
if [ ! -d "/tmp/$USER" ]
then
   mkdir /tmp/$USER
fi

#make sure the error_attachments folder is empty
if [ ! -d "$userTaskPath/error_attachments" ]; 
then
   mkdir $userTaskPath/error_attachments
else
   rm -r $userTaskPath/error_attachments
   mkdir $userTaskPath/error_attachments
fi


##########################
######### ANALYZE ########
##########################

# prepare sources for ISE
. /opt/Xilinx/14.7/ISE_DS/ISE/.settings64.sh /opt/Xilinx/14.7/ISE_DS/ISE

#entity, not from user, should have no errors
vhpcomp ALU.vhdl
RET=$? 
if [ "$RET" -ne "$zero" ]
then
   logPrefix && echo "${logPre}Error with Task $2 entity for user with ID $1";
   echo "Something went wrong with the task $2 test generation. This is not your fault. We are working on a solution" > $userTaskPath/error_msg
   exit 3 
fi

#testbench, not from user, should have no errors
vhpcomp ALU_tb_$1_Task$2.vhdl
RET=$? 
if [ "$RET" -ne "$zero" ]
then
   logPrefix && echo "${logPre}Error with Task $2 testbench for user with ID $1";
   echo "Something went wrong with the task $2 test generation. This is not your fault. We are working on a solution" > $userTaskPath/error_msg
   exit 3 
fi

#this is the file from the user
sed -i '/^--/ d' ALU_beh.vhdl

vhpcomp ALU_beh.vhdl 2> /tmp/$USER/tmp_Task$2_User$1
RET=$?

if [ "$RET" -eq "$zero" ]
then
   logPrefix && echo "${logPre}Task$2 analyze success for user with ID $1!"
else
   logPrefix && echo "Task$2 analyze FAILED for user with ID $1!"
   cd $autosubPath
   echo "Analyzation of your submitted behavior file failed:" >$userTaskPath/error_msg
   cat /tmp/$USER/tmp_Task$2_User$1 | grep ERROR >> $userTaskPath/error_msg
   exit 1 
fi


##########################
## TASK CONSTRAINT CHECK #
##########################
cd $userTaskPath
touch file

sed -i 's:--.*$::g' ALU_beh.vhdl
cat ALU_beh.vhdl | tr '[:upper:]' '[:lower:]' >> file
cat file | tr -d " \t\n\r" >> file
rising=$(egrep -o "rising_edge" file | wc -l)
rising_event=$(egrep -o "clk'eventandclk='1'" file | wc -l)

#check the occurrence of phrases concerning rising edge
if ( [ "$rising" -ne "$zero" ] || [ "$rising_event" -ne "$zero" ] )
then
  logPrefix && echo "${logPre}Task$2 using clock cycle for user with ID $1!"
else
   logPrefix && echo "${logPre}Task$2 constraint check FAILED for user with ID $1!"
   cd $autosubPath
   echo "You are not using rising edge of the clock signal.">$userTaskPath/error_msg
   exit 1 
fi
##########################
######## ELABORATE #######
##########################
fuse -top ALU_tb
RET=$?

# to detect if the student changes the entity and uses the modified one in the behavior code
touch file
cat $userTaskPath/fuse.log | grep ERROR:HDLCompiler:1566 >> $userTaskPath/file
tmp=$(sed 's/[0-9]*//g' file)
echo "$tmp" > file
tmp=$(sed 's~[^[:alnum:]/]\+~~g' file)
echo "$tmp" > file
wrongEntity=$(egrep -o "ALUtbTaskvhdlLineExpressionhaselementsformalaexpects" file | wc -l)

if [ "$RET" -eq "$zero" ]
then
   logPrefix && echo "${logPre}Task$2 elaboration success for user with ID $1!"
elif [ "$wrongEntity" -ne "$zero" ]
then
   echo "Elaboration with your submitted behavior file failed because you have changed the entity file." >$userTaskPath/error_msg
   exit 1 
   else
   echo "Task$2 elaboration FAILED for user with ID $1!"
   cd $autosubPath
   echo "Elaboration with your submitted behavior file failed:" >$userTaskPath/error_msg
   cat $userTaskPath/fuse.log | grep ERROR >> $userTaskPath/error_msg
   exit 1 
fi

##########################
####### SIMULATION #######
##########################

./x.exe -tclbatch isim.cmd 
egrep -oq "Success" isim.log
RET=$?


if [ "$RET" -eq "$zero" ]
then
    logPrefix && echo "${logPre}Functionally correct for Task$2 for user with ID $1!"
    #cat $userTaskPath/isim.log | grep Note >> $userTaskPath/error_msg
    exit 0
else #; timeout returns 124 if it had to kill process  
    cd $autosubPath
    logPrefix && echo "${logPre}Wrong behavior for Task$2 for user with ID $1!"
    echo "Your submitted behavior file does not behave like specified in the task description:" >$userTaskPath/error_msg
    cat $userTaskPath/isim.log | grep Failure >> $userTaskPath/error_msg
    cat $userTaskPath/isim.log | grep -oP 'Error: \K.*' >> $userTaskPath/error_msg

    exit 1  
fi
