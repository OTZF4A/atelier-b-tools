#!/bin/bash

# 1. Check if the current directory is empty
# 'ls -A' lists all files including hidden ones, excluding . and ..
if [ "$(ls -A)" ]; then
     echo "Error: Directory is not empty! Execution aborted."
     exit 1
fi

# ---- (semi) automatic detection of location of Atelier B installation

# candidate AtelierB installation directories - detecting based on known parent locations + the presence of etc/AtelierB file that should exist within any Atelier B installation directory

# according to AtelierB installation documentation at https://www.atelierb.eu/wp-content/uploads/2024/11/installation-guide-community.pdf
# the AtelierB installation directory can live under the following directory (listed by platform):
# Linux: /opt/<some atelierb version string>/
# MacOSX: /Applications/<some atelierb version string>/Contents/Resources/
# Windows (under git bash): "$PROGRAMFILES"/<some atelierb version string>/
#
# we don't know what the current version string is (in fact there might be multiple separate AtelierB installations coexisting), but the directory will have an etc/AtelierB file present
# so we match to (directories containing) that file, and once the existing file(s) is/are found, we cut off the last two parts of the full file path to arrive at the AtelierB installation directory itself
#
DETECTION_FILE_PATH="etc/AtelierB"

# we now use Bash globbing to find out which of these candidates (if any) are actually existing on this machine
shopt -s nullglob # drop patterns from the list for items that were not found, instead of keeping the unexpanded patterns (= we use this to only keep the existing directories in our list)
shopt -s nocaseglob # case-insensitive matching
ATELIERB_GLOBAL_CONFIGURATION_FILE_CANDIDATES=({/opt,/Applications,"$PROGRAMFILES"}/*Atelier*/{Contents/Resources/,}"$DETECTION_FILE_PATH")

# debug: duplicating the entry on my machine, to emulate multiple AtelierB installations, to elicit the directory choice prompt for testing
#ATELIERB_GLOBAL_CONFIGURATION_FILE_CANDIDATES=({/opt,/Applications,"$PROGRAMFILES","$PROGRAMFILES"}/*Atelier*/{Contents/Resources/,}"$DETECTION_FILE_PATH")

shopt -u nullglob
shopt -u nocaseglob

shopt -s lastpipe # requesting the last member of the pipe to be run in this shell, so that its results/effects remain visible in this shell
dirname "${ATELIERB_GLOBAL_CONFIGURATION_FILE_CANDIDATES[@]}" | mapfile -t ATELIERB_GLOBAL_ETC_DIRECTORY_CANDIDATES
dirname "${ATELIERB_GLOBAL_ETC_DIRECTORY_CANDIDATES[@]}" | mapfile -t ATELIERB_INSTALLATION_DIRECTORY_CANDIDATES
shopt -u lastpipe

# debug: clear all found
#unset ATELIERB_INSTALLATION_DIRECTORY_CANDIDATES[@]

until [ -f "$ATELIERB_PATH"/"$DETECTION_FILE_PATH" ]; do
	OLD_IFS="$IFS"
	IFS=""

	case ${#ATELIERB_INSTALLATION_DIRECTORY_CANDIDATES[@]} in
		0)
			echo Found no Atelier B installations.
			PROMPT1="Please enter a pathname for the Atelier B you would like to use (or press Ctrl-C to abort): "
			read -r -p "$PROMPT1"
			if [ -d "$REPLY" -a -f "${REPLY}"/"$DETECTION_FILE_PATH" ] ; then
				ATELIERB_PATH="${REPLY}"
			else
				echo could not find an Atelier B installation in "$REPLY"
				echo please try again.
			fi
			;;
		1)
			ATELIERB_PATH="${ATELIERB_INSTALLATION_DIRECTORY_CANDIDATES[0]}"
			;;
		*)
			PROMPT1="found ${#ATELIERB_INSTALLATION_DIRECTORY_CANDIDATES[@]} Atelier B installation directories, which one would you like to use?"
			PS3="please enter a number from the list, or input a pathname if you want an Atelier B that is not listed above (or press Ctrl-C to abort): "

			echo "$PROMPT1"
			select ATELIERB_PATH in "${ATELIERB_INSTALLATION_DIRECTORY_CANDIDATES[@]}";
			do
				if [ -n "$ATELIERB_PATH" ] ; then
					echo You have chosen: "$ATELIERB_PATH"
					break
				else
					echo You entered: $REPLY
					if [ -d "$REPLY" -a -f '${REPLY}'/"$DETECTION_FILE_PATH" ] ; then
						ATELIERB_PATH=${REPLY}
					else
						echo could not find an Atelier B installation in "$REPLY"
						echo please try again.
					fi
					break
				fi
			done
	esac
	IFS="$OLD_IFS"
done

echo Using Atelier B installation in: "$ATELIERB_PATH"

# ---- end of (semi) automatic detection of location of Atelier B installation

# 4. Create the 'bdb' and 'Archives' directories
mkdir -p "bdb" "Archives"

# 5. Get the absolute path of the 'bdb' directory
BDB_ABS_PATH=$(realpath "bdb")

# 6. Create the 'AtelierB' configuration file
cat <<EOF > AtelierB
!===========================================================================
! AtelierB Global resources
!===========================================================================
!
! Tools resources
!
ATB*ATB*Logic_Solver_Command:krt -a c70000d3000e100g10000h10000m10000000n130000o110400s60000t1100x5000y5500
ATB*ATB*TypeChecker_Command:TC.kin
ATB*ATB*Xref_Command:xref
ATB*ATB*Proof_Obligations_Generator_Command:PO.kin
ATB*ATB*Proof_Obligations_Generator_NG_Command:pog
ATB*ATB*Proof_Obligations_Generator_EvB_Command:pogevb
ATB*ATB*Proof_Obligations_Generator_NG:TRUE
ATB*ATB*Binst_Command:binst
ATB*ATB*Prover_Command:MU.kin
ATB*ATB*KParser_Command:pk -a m20000
ATB*ATB*Predicate_Prover_Command:PP.kin
ATB*ATB*BED_Command:bed
ATB*ATB*Read_PMI_Command:READPMI.kin
ATB*ATB*ML_Command:ML.kin
ATB*ATB*ComenC_Translator_Command:b2c
ATB*ATB*Delta_Component_Command:DELTA3.kin
ATB*ATB*Bart_Refiner_Command:bart
ATB*ATB*BBeautifuler_Command:BBeautifuler
ATB*ATB*Print_Command:bprint
ATB*ATB*Bxml_Command:bxml
ATB*ATB*B_Compiler_Command:bcomp
ATB*ATB*External_Proof_Command:extprove
ATB*ATB*Replay_External_Proof_Command:extreplay
ATB*ATB*Proof_Metrics:extmetrics
ATB*ATB*Rust_Translator_Command:b2rust

!===========================================================================
! TypeChecker Resource : Enable Local Operations
!===========================================================================
ATB*TC*Enable_Local_Operations:TRUE

! Set to true not to use prover extensions defined in the 3.7 version
ATB*PR*Pr_3_6_compatibility:FALSE

!===========================================================================
! Resources to use third-party provers
!===========================================================================
ATB*Proof*Why3Writer:po2why
ATB*Proof*Pog_Smt_Simplified_Encode:pog2smt
ATB*Proof*Pog_Smt_PP_Encode:ppTransSmt
ATB*Proof*Smt_Simplified_Read_Status:simple_smt_solver_reader
ATB*Proof*Smt_Read_Status:smt_solver_reader
ATB*Proof*Pog_TPTP_PP_Encode:ppTransTPTP
ATB*Proof*TPTP_Read_Status:tptp_reader
ATB*Proof*Pog_Why_Encode:pog2why
ATB*Proof*AltErgo_Read_Status:altergo_reader
!===========================================================================
! Installation path dependent resources
!===========================================================================
ATB*BART*RefinerFile:${ATELIERB_PATH}/share/bart/PatchRaffiner.rmf
ATB*B2RUST*Configuration_Directory:${ATELIERB_PATH}/share/b2rust/config/
ATB*ATB*Atelier_Database_Directory:${BDB_ABS_PATH}
EOF

echo "Success: 'bdb' and 'Archives' directories, and 'AtelierB' config file have been created."
