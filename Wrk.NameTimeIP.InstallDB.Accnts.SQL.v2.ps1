<#

This DSC script takes the inputs under the param section and sets the IP address, default gateway, DNS server, disables IPv6, renames the server, updates the computer description, and sets the time zone to GMT and adds it to the DEV2.test doamin created with the ADDS script. It then installs SQL Server.

Follow these steps:
Create a new VM with Windows Server 2016/2019 OS. If you want to install SQL on another drive it must be created, formatted and added to the VM before the script runs.

Make sure the following DSC modules from https://www.powershellgallery.com/ are copied to C:\Program Files\WindowsPowerShell\Modules
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module NetworkingDsc
    Import-DscResource -Module ComputerManagementDsc
    Import-DscResource -Module xNetworking
    Import-DSCResource -ModuleName xDnsServer
    Import-DscResource -ModuleName SqlServerDsc
    Import-DscResource -ModuleName xSqlServer
	
Create a folder called C:\TEMP

Copy the file Wrk.NameTimeIP.InstallDB.Accnts.SQL.v2.ps1 to C:\TEMP

Open PowerShell ISE

Run the following command: Set-ExecutionPolicy -ExecutionPolicy Unrestricted

Open C:\Temp\Wrk.NameTimeIP.InstallDB.Accnts.SQL.v2.ps1 inside PowerShell ISE

Validate there are no errors in the script ~~~~~ Red Squiggley Lines are Bad

Run the script within PowerShell ISE

PowerShell ISE will prompt you for 4 credentials: Domain Admin, Network Share Access, DEV2\SQL.Install, and the DEV2\SQL.Services

The machine will reboot multiple times

If you want to change the Name, Default Log location, etc from the default in the script just update the corresponding Parameter String in the Account Credential and Variable Region at the top of the script

#>

Set-ExecutionPolicy -ExecutionPolicy Unrestricted

<# Create c:\TEMP directory #>
	md c:\TEMP

<# Change to c:\TEMP directory #>
	cd C:\TEMP

<# Determine Name of the Network Adapter in this OS #>
	$NetAdapterName = Get-NetAdapter -Name "Ethernet*"
	$NetAdapterName = $NetAdapterName.ifAlias

<# Account Credentials #>
 
        $Credential = Get-Credential -UserName 'DEV2\administrator' -Message "Domain Admin User Name and Password"
		
        $SqlShareCredential = Get-Credential -UserName 'DEV2\administrator' -Message "Domain Account User Name and Password"

        $SqlInstallCredential = Get-Credential -UserName 'DEV2\SQL.Install' -Message "DEV2\SQL.Install User Name and Password"
   
        $SqlAdministratorCredential = $SqlInstallCredential, # Sets the SQL Admin credential to the SQL Install Credential called for in the previous line
   
        $SqlServiceCredential = Get-Credential -UserName 'DEV2\SQL.Services' -Message "DEV2\SQL.Services User Name and Password"
   
        $SqlAgentServiceCredential = $SqlServiceCredential	# Sets the SQL Agent Service credential to the SQL Service Credential called for in the previous line
		
		
Configuration Wrk.NameTimeIP.InstallDB.Accnts.SQL
{


<# Account Credential and Variable Region #>

    param
    (
<# Server Name #>	
        [Parameter()]
        [String]
        $Name = 'SQL',

<# Server Description #>		
	[Parameter()]
        [String]
        $ComputerDescription = 'SQL Database Server',

<# Server IP Address #>		
	[Parameter()]
        [String]
        $IPAddress = '192.168.87.203',

<# Server Default Gateway #>		
	[Parameter()]
        [String]
        $DefaultGateway = '192.168.87.1',

<# DNS Server IP Address #>		
	[Parameter()]
        [String]
        $DNS = '192.168.87.201',

<# FQDN = HostName.DomainName.TopLevelDomainName example = server.'DEV2'.test #>
<# Domain Name #>		
	[Parameter()]
        [String]
	$Domain = 'dev2',
		
<# FQDN = HostName.DomainName.TopLevelDomainName example = server.dev2.'TEST' #>
<# Top Level Domain Name #>		
	[Parameter()]
        [String]
	$TopLevelDomain = 'test',

<# Combined AD Domain Name #>

	[Parameter()]
        [String]
	$DomainFQDN = $Domain + '.' + $TopLevelDomain
		
<# Share Containing .NET Framework 3.5 #>
	[Parameter()]
        [String]		
	$NetFramework35Share = '\\ADDS\sxs',

<# Share Containing SQL2016 Binaries Extracted from ISO #>
	[Parameter()]
        [String]		
	$SQL2016BinariesSource = '\\ADDS\SQL2016Binaries\',

<# Local Folder to Hold the SQL2016 Binaries #>
	[Parameter()]
        [String]		
	$SQL2016BinariesDestination = 'D:\SQL2016Binaries',

<# Location for Shared Directory #>
	[Parameter()]
        [String]			
	$InstallSharedDir = 'D:\Program Files\Microsoft SQL Server',

<# Location for Shared WOW Directory #>		
	[Parameter()]
        [String]			
	$InstallSharedWOWDir  = 'D:\Program Files (x86)\Microsoft SQL Server',

<# Location for the SQL Instace #>		
	[Parameter()]
        [String]			
	$InstanceDir = 'D:\Program Files\Microsoft SQL Server',

<# Location for SQL Data Directory #>		
	[Parameter()]
        [String]			
	$InstallSQLDataDir = 'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data',

<# Location for SQL User DB #>		
	[Parameter()]
        [String]			
	$SQLUserDBDir = 'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data',

<# Location for SQL DB Log #>		
	[Parameter()]
        [String]			
	$SQLUserDBLogDir = 'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data',

<# Location for the SQL TEMP DB #>		
	[Parameter()]
        [String]			
	$SQLTempDBDir = 'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data',

<# Location for SQL TEMP DB Log #>		
	[Parameter()]
        [String]			
	$SQLTempDBLogDir = 'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data',

<# Location for SQL Backups #>		
	[Parameter()]
        [String]			
	$SQLBackupDir = 'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup',		

<# Section for MSOLAP Settings, If not using OLAP Feature This Section is NOT used #>
<# Location for SQL OLAP Config #>
	[Parameter()]
        [String]		
	$ConfigDir = 'D:\MSOLAP\Config',

<# Location for SQL OLAP Data #>
	[Parameter()]
        [String]
	$DataDir = 'D:\MSOLAP\Data',

<# Location for SQL OLAP Log #>		
	[Parameter()]
        [String]		
	$LogDir = 'D:\MSOLAP\Log',

<# Location for SQL OLAP Backup #>		
	[Parameter()]
        [String]		
	$BackupDir = 'D:\MSOLAP\Backup',

<# Location for SQL OLAP TEMP #>		
	[Parameter()]
        [String]		
	$TempDir = 'D:\MSOLAP\Temp'

    )

<# DSC Module Region #>

    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module NetworkingDsc
    Import-DscResource -Module ComputerManagementDsc
    Import-DscResource -Module xNetworking
    Import-DSCResource -ModuleName xDnsServer
    Import-DscResource -ModuleName SqlServerDsc
    Import-DscResource -ModuleName xSqlServer	


<# DSC Node Region #>
	
	Node $AllNodes.NodeName
    {
 	
	NetAdapterBinding DisableIPv6
        {
            InterfaceAlias = $NetAdapterName
            ComponentId    = 'ms_tcpip6'
            State          = 'Disabled'
        } 

	IPAddress SetIPAddress
        {
            IPAddress      = $IPAddress
            InterfaceAlias = $NetAdapterName
            AddressFamily  = 'IPV4'
	    DependsOn	   = '[NetAdapterBinding]DisableIPv6'
        }

	DnsServerAddress SetDnsServerAddress
        {
            Address        = $DNS
            InterfaceAlias = $NetAdapterName
            AddressFamily  = 'IPv4'
            DependsOn	   = '[IPAddress]SetIPAddress'
        }

         DefaultGatewayAddress SetDefaultGateway
        {
            Address        = $DefaultGateway
            InterfaceAlias = $NetAdapterName
            AddressFamily  = 'IPv4'
            DependsOn	   = '[DnsServerAddress]SetDnsServerAddress'
        }
		
	TimeZone SetTimeZoneToGMT
        {
            IsSingleInstance 	= 'Yes'
            TimeZone         	= 'GMT Standard Time' # Must be a valid Microsoft Time Zone
	    DependsOn	        = '[DefaultGatewayAddress]SetDefaultGateway'
        }

	Computer JoinDomain
        {
            Name          	= 'SQL'
            Description 	= $ComputerDescription
	    DomainName 		= 'DEV2.TEST'
            Credential 		= $Credential # Credential to join to domain
	    DependsOn	   	= '[TimeZone]SetTimeZoneToGMT'
        }
        		
	PendingReboot JoinDomain
        {
            Name                        = 'JoinDomain'
            SkipComponentBasedServicing = $false
            SkipWindowsUpdate           = $false
            SkipPendingFileRename       = $false
            SkipPendingComputerRename   = $false
            SkipCcmClientSDK            = $false
            DependsOn                   = '[Computer]JoinDomain'
        }


<# SQL Accounts Group in Local Admin Region #>

	Group SQLAccounts
        {
            GroupName            = 'Administrators'
            Ensure		 = 'Present'
            MembersToInclude	 = 'DEV2\SQLAccounts'
	    Credential 		 = $Credential
	    PsDscRunAsCredential = $Credential
	    DependsOn	   	 = '[Computer]JoinDomain'
        }

<# SQL Prerequisites for SQL Server Region #>

         WindowsFeature 'NetFramework35'
        {
            Name   		    = 'NET-Framework-Core'
            Source 		    = $NetFramework35Share # Assumes built-in Everyone has read permission to the share and path.
            Ensure 		    = 'Present'
	    PsDscRunAsCredential    = $SqlShareCredential
            DependsOn 		    = '[Group]SQLAccounts'
        }

        WindowsFeature 'NetFramework45'
        {
            Name  	= 'NET-Framework-45-Core'
            Ensure 	= 'Present'
	    DependsOn 	= '[WindowsFeature]NetFramework35'
        }

         File 'DirectoryCopy'
        {
            Ensure 			= 'Present' # Ensure the directory is Present on the target node.
            Type 			= 'Directory' # The default is File.
            Recurse 			= $true # Recursively copy all subdirectories.
            SourcePath 			= $SQL2016BinariesShare
            DestinationPath 		= $SQL2016BinariesDestination
	    PsDscRunAsCredential   	= $SqlShareCredential
	    DependsOn 			= '[WindowsFeature]NetFramework45'
        }



<# Install SQL Server Region #>


        SqlSetup 'InstallDefaultInstance'
        {
            InstanceName           = 'MSSQLSERVER'
            Features               = 'SQLENGINE'
            SQLCollation           = 'SQL_Latin1_General_CP1_CI_AS'
            SQLSvcAccount          = $SqlServiceCredential
            AgtSvcAccount          = $SqlAgentServiceCredential
            ASSvcAccount           = $SqlServiceCredential
            SQLSysAdminAccounts    = 'DEV2\administrator', $SqlAdministratorCredential.UserName
            ASSysAdminAccounts     = 'DEV2\administrator', $SqlAdministratorCredential.UserName
            InstallSharedDir       = $InstallSharedDir   
            InstallSharedWOWDir    = $InstallSharedWOWDir
            InstanceDir            = $InstanceDir        
            InstallSQLDataDir      = $InstallSQLDataDir  
            SQLUserDBDir           = $SQLUserDBDir       
            SQLUserDBLogDir        = $SQLUserDBLogDir    
            SQLTempDBDir           = $SQLTempDBDir       
            SQLTempDBLogDir        = $SQLTempDBLogDir    
            SQLBackupDir           = $SQLBackupDir       
            ASServerMode           = 'TABULAR'
            ASConfigDir            = $ConfigDir
            ASDataDir              = $DataDir
            ASLogDir               = $LogDir 
            ASBackupDir            = $BackupDir
            ASTempDir              = $TempDir 
            SourcePath             = $SQL2016BinariesDestination # This is the location the files are copied to in the File 'DirectoryCopy' section
            UpdateEnabled          = 'False'
            ForceReboot            = $false

            PsDscRunAsCredential   = $SqlInstallCredential

            DependsOn              = '[WindowsFeature]NetFramework35', '[WindowsFeature]NetFramework45'
        }
		
		<# SqlServerMaxDop Set_SQLServerMaxDop_ToOne
        {
            Ensure               = 'Present'
            DynamicAlloc         = $false
            MaxDop               = '1'
            ServerName           = 'SQL'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
         }
		#>
	PendingReboot PostInstall
        {
            Name                        = 'PostInstall'
            SkipComponentBasedServicing = $false
            SkipWindowsUpdate           = $false
            SkipPendingFileRename       = $false
            SkipPendingComputerRename   = $false
            SkipCcmClientSDK            = $false
            DependsOn 			= '[SqlServerMaxDop]Set_SQLServerMaxDop_ToOne'
        }
		

<# SQL Accounts Group in Local Admin Region #>

	SqlServerLogin 'SP.Setup'
        {
            Ensure               = 'Present'
            Name                 = 'DEV2\SP.Setup'
            LoginType            = 'WindowsUser'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }
        
        SqlServerLogin 'SP.Farm'
        {
            Ensure               = 'Present'
            Name                 = 'DEV2\SP.Farm'
            LoginType            = 'WindowsUser'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
			
            PsDscRunAsCredential = $SqlAdministratorCredential
        }
		
		# Section that adds user accounts to SQL Server Roles
		# must add single quotes before and after each user account and a comma between each account on the Members line
		
        SqlServerRole Add_SP.Setup_ServerRole_ServerAdmin
        {
            Ensure               = 'Present'
            ServerRoleName       = 'serveradmin'
            Members              = 'DEV2\sp.setup','DEV2\sp.farm'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }

        SqlServerRole Add_SP.Setup_ServerRole_SetupAdmin
        {
            Ensure               = 'Present'
            ServerRoleName       = 'SetupAdmin'
            Members              = 'DEV2\sp.setup','DEV2\sp.farm'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }			

        SqlServerRole Add_SP.Setup_ServerRole_DBCreator
        {
            Ensure               = 'Present'
            ServerRoleName       = 'DBCreator'
            Members              = 'DEV2\sp.setup','DEV2\sp.farm'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }
		
        SqlServerRole Add_SP.Setup_ServerRole_securityadmin
        {
            Ensure               = 'Present'
            ServerRoleName       = 'securityadmin'
            Members              = 'DEV2\sp.setup','DEV2\sp.farm'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }
		
        SqlServerRole Add_SP.Setup_ServerRole_processadmin
        {
            Ensure               = 'Present'
            ServerRoleName       = 'processadmin'
            Members              = 'DEV2\sp.setup','DEV2\sp.farm'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }
		
        SqlServerRole Add_SP.Setup_ServerRole_bulkadmin
        {
            Ensure               = 'Present'
            ServerRoleName       = 'bulkadmin'
            Members              = 'DEV2\sp.setup','DEV2\sp.farm'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }
		
        SqlServerRole Add_SP.Setup_ServerRole_diskadmin
        {
            Ensure               = 'Present'
            ServerRoleName       = 'diskadmin'
            Members              = 'DEV2\sp.setup','DEV2\sp.farm'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }
		
     }
}

$cd = @{
    AllNodes = @(
        @{
            NodeName 			= 'localhost'
            PsDscAllowDomainUser 	= $true
            PsDscAllowPlainTextPassword = $true
            ActionAfterReboot 		= 'ContinueConfiguration';
            RebootNodeIfNeeded 		= $true;
        }
    )
}

[DSCLocalConfigurationManager()]
Configuration LCMConfig
{
    Node 'localhost'
    {
        Settings
        {
            ActionAfterReboot 	= 'ContinueConfiguration';
            RebootNodeIfNeeded 	= $true;
	    RefreshMode 	= 'Push'
        }
    }
}
LCMConfig
Set-DscLocalConfigurationManager LCMConfig -Force -Verbose

Wrk.NameTimeIP.InstallDB.Accnts.SQL -ConfigurationData $cd

Start-DscConfiguration Wrk.NameTimeIP.InstallDB.Accnts.SQL -Force -Wait -Verbose
