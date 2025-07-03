GAMBMG_V2 for Windows Powershell - 6/3/2025

GAMBMG_V2 for MacOS Shell/Bash - 7/2/2025

## macOS Usage

For macOS users a bash rewrite is provided as `GAMBMG.sh`. The script
mirrors the behaviour of the Windows PowerShell version but can be run
directly from a standard Terminal. Ensure `gam` is installed and
available on your `PATH` before running the script.

	This powershell script is designed to automate the creation 
	of Google Groups for the Burning Man Project. 
	
	GAM version 4.65.82 or greater, though GAMADV-X is preferred.
		https://github.com/taers232c/GAMADV-X
	Template Groups are required to provide settings to be copied to the new group.
	
Author:		DFtI for The Burning Man Project User Success department

Email:		devin@burningman.org

		Shamelessly stolen from Eric Haugen's Original bash shell script of the same name.

gambmg usage:

    -group <groupName>        : The group email prefix (without domain)
    
    -typeName <alias|announce|discussion> : Type of group
    
    -owner <ownerEmail>       : Owner email prefix (without domain)
    
    -mailPref <allmail|nomail>: Whether owner receives mail
    
    -dept <department>        : Department name
    
    -Force <y/n>              : Skip confirmation prompt (default no)

    -TestMode <y/n>           : Dry run mode, no changes made (default no)
    

If you run gambmg with no parameters, you will be prompted interactively.

Updates:

	7/2/25 	Added additional add-user loop after group creation.
               Added **curated** group summary after group creation, and if the group address already exists.
  	7/2/25 	Added MacOS Bash Version in GAMBMG.sh
