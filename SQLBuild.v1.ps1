<#
    .EXAMPLE
    Text Goes Here

#>

Set-ExecutionPolicy -ExecutionPolicy Unrestricted

<# Create c:\TEMP directory #>
md c:\TEMP

<# Change to c:\TEMP directory #>
cd C:\TEMP


Configuration NameTimeIP
{

########################################################
# Account Credential and Variable Region
########################################################

    param
    (
        [Parameter()]
        [String]
        $Name = 'SQL',
		
		[Parameter()]
        [String]
        $ComputerDescription = 'SQL Database Server',
		
		[Parameter()]
        [String]
        $IPAddress = '192.168.87.203',
		
		[Parameter()]
        [String]
        $DefaultGateway = '192.168.87.1',
		
		[Parameter()]
        [String]
        $DNS = '192.168.87.201',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential,
		
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        $SqlShareCredential,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        $SqlInstallCredential,
   
        [Parameter()]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        $SqlAdministratorCredential = $SqlInstallCredential,
   
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        $SqlServiceCredential,
   
        [Parameter()]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        $SqlAgentServiceCredential = $SqlServiceCredential			
		
    )


########################################################
# DSC Module Region
########################################################

    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module NetworkingDsc
	Import-DscResource -Module ComputerManagementDsc
	Import-DscResource -Module xNetworking
	Import-DSCResource -ModuleName xDnsServer
    Import-DscResource -ModuleName SqlServerDsc
    Import-DscResource -ModuleName xSqlServer	

########################################################
# DSC Node Region
########################################################
	
	Node $AllNodes.NodeName
    {
 	
		NetAdapterBinding DisableIPv6
        {
            InterfaceAlias = 'Ethernet 3'
            ComponentId    = 'ms_tcpip6'
            State          = 'Disabled'
        } 

		IPAddress SetIPAddress
        {
            IPAddress      = $IPAddress
            InterfaceAlias = 'Ethernet 3'
            AddressFamily  = 'IPV4'
			DependsOn	   = '[NetAdapterBinding]DisableIPv6'
        }

		DnsServerAddress SetDnsServerAddress
        {
            Address        = $DNS
            InterfaceAlias = 'Ethernet 3'
            AddressFamily  = 'IPv4'
            DependsOn	   = '[IPAddress]SetIPAddress'
        }

         DefaultGatewayAddress SetDefaultGateway
        {
            Address        = $DefaultGateway
            InterfaceAlias = 'Ethernet 3'
            AddressFamily  = 'IPv4'
            DependsOn	   = '[DnsServerAddress]SetDnsServerAddress'
        }
		
		TimeZone SetTimeZoneToGMT
        {
            IsSingleInstance 	= 'Yes'
            TimeZone         	= 'GMT Standard Time'
			DependsOn	   		= '[DefaultGatewayAddress]SetDefaultGateway'
        }

		Computer JoinDomain
        {
            Name          	= 'SQL'
            Description 	= $ComputerDescription
			DomainName 		= 'DEV2.TEST'
            Credential 		= $Credential # Credential to join to domain
			DependsOn	   	= '[TimeZone]SetTimeZoneToGMT'
        }
        		
		PendingReboot XYZ
        {
            Name                        = 'ABC'
            SkipComponentBasedServicing = $false
            SkipWindowsUpdate           = $false
            SkipPendingFileRename       = $false
            SkipPendingComputerRename   = $false
            SkipCcmClientSDK            = $false
            DependsOn                   = '[Computer]JoinDomain'
        }

########################################################
# SQL Accounts Group in Local Admin Region
########################################################

		Group SQLAccounts
        {
            GroupName        = 'Administrators'
            Ensure           = 'Present'
            MembersToInclude = 'Dev2\SQLAccounts'
			Credential = $Credential
			PsDscRunAsCredential = $Credential
			DependsOn	   	 = '[Computer]JoinDomain'
        }


########################################################
# SQL Prerequisites for SQL Server Region
########################################################


         WindowsFeature 'NetFramework35'
        {
            Name   = 'NET-Framework-Core'
            Source = '\\ADDS\sxs' # Assumes built-in Everyone has read permission to the share and path.
            Ensure = 'Present'
            DependsOn = '[Group]SQLAccounts'
        }

        WindowsFeature 'NetFramework45'
        {
            Name   = 'NET-Framework-45-Core'
            Ensure = 'Present'
        }

         File 'DirectoryCopy'
        {
            Ensure = 'Present' # Ensure the directory is Present on the target node.
            Type = 'Directory' # The default is File.
            Recurse = $true # Recursively copy all subdirectories.
            SourcePath = '\\ADDS\SQL2016Binaries\'
            DestinationPath = 'D:\SQL2016Binaries'
			PsDscRunAsCredential   = $SqlInstallCredential
        }


########################################################
# Install SQL Server Region
########################################################

        SqlSetup 'InstallDefaultInstance'
        {
            InstanceName           = 'MSSQLSERVER'
            Features               = 'SQLENGINE'
            SQLCollation           = 'SQL_Latin1_General_CP1_CI_AS'
            SQLSvcAccount          = $SqlServiceCredential
            AgtSvcAccount          = $SqlAgentServiceCredential
            ASSvcAccount           = $SqlServiceCredential
            SQLSysAdminAccounts    = 'dev2\administrator', $SqlAdministratorCredential.UserName
            ASSysAdminAccounts     = 'dev2\administrator', $SqlAdministratorCredential.UserName
            InstallSharedDir       = 'D:\Program Files\Microsoft SQL Server'
            InstallSharedWOWDir    = 'D:\Program Files (x86)\Microsoft SQL Server'
            InstanceDir            = 'D:\Program Files\Microsoft SQL Server'
            InstallSQLDataDir      = 'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data'
            SQLUserDBDir           = 'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data'
            SQLUserDBLogDir        = 'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data'
            SQLTempDBDir           = 'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data'
            SQLTempDBLogDir        = 'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data'
            SQLBackupDir           = 'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup'
            ASServerMode           = 'TABULAR'
            ASConfigDir            = 'D:\MSOLAP\Config'
            ASDataDir              = 'D:\MSOLAP\Data'
            ASLogDir               = 'D:\MSOLAP\Log'
            ASBackupDir            = 'D:\MSOLAP\Backup'
            ASTempDir              = 'D:\MSOLAP\Temp'
            SourcePath             = 'D:\SQL2016Binaries'#'\\192.168.86.200\SQL2016Binaries'
            UpdateEnabled          = 'False'
            ForceReboot            = $false

            PsDscRunAsCredential = $SqlInstallCredential

            DependsOn            = '[WindowsFeature]NetFramework35', '[WindowsFeature]NetFramework45'
        }
		
		SqlServerMaxDop Set_SQLServerMaxDop_ToOne
        {
            Ensure               = 'Present'
            DynamicAlloc         = $false
            MaxDop               = 1
            ServerName           = 'SQL'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }
		
		PendingReboot PostInstall
        {
            Name                        = 'PostInstall'
            SkipComponentBasedServicing = $false
            SkipWindowsUpdate           = $false
            SkipPendingFileRename       = $false
            SkipPendingComputerRename   = $false
            SkipCcmClientSDK            = $false
            DependsOn = '[SqlServerMaxDop]Set_SQLServerMaxDop_ToOne'
        }
		
########################################################
# SQL Accounts Group in Local Admin Region
########################################################

		        SqlServerLogin 'SP.Setup'
        {
            Ensure               = 'Present'
            Name                 = 'dev2\SP.Setup'
            LoginType            = 'WindowsUser'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }
        
        SqlServerLogin 'SP.Farm'
        {
            Ensure               = 'Present'
            Name                 = 'dev2\SP.Farm'
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
            Members              = 'dev2\sp.setup','dev2\sp.farm'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }

        SqlServerRole Add_SP.Setup_ServerRole_SetupAdmin
        {
            Ensure               = 'Present'
            ServerRoleName       = 'SetupAdmin'
            Members              = 'dev2\sp.setup','dev2\sp.farm'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }			

        SqlServerRole Add_SP.Setup_ServerRole_DBCreator
        {
            Ensure               = 'Present'
            ServerRoleName       = 'DBCreator'
            Members              = 'dev2\sp.setup','dev2\sp.farm'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }
		
        SqlServerRole Add_SP.Setup_ServerRole_securityadmin
        {
            Ensure               = 'Present'
            ServerRoleName       = 'securityadmin'
            Members              = 'dev2\sp.setup','dev2\sp.farm'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }
		
        SqlServerRole Add_SP.Setup_ServerRole_processadmin
        {
            Ensure               = 'Present'
            ServerRoleName       = 'processadmin'
            Members              = 'dev2\sp.setup','dev2\sp.farm'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }
		
        SqlServerRole Add_SP.Setup_ServerRole_bulkadmin
        {
            Ensure               = 'Present'
            ServerRoleName       = 'bulkadmin'
            Members              = 'dev2\sp.setup','dev2\sp.farm'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }
		
        SqlServerRole Add_SP.Setup_ServerRole_diskadmin
        {
            Ensure               = 'Present'
            ServerRoleName       = 'diskadmin'
            Members              = 'dev2\sp.setup','dev2\sp.farm'
            ServerName           = 'sql.dev2.test'
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $SqlAdministratorCredential
        }
		
     }
}


$cd = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PsDscAllowDomainUser = $true
            PsDscAllowPlainTextPassword = $true
            ActionAfterReboot = 'ContinueConfiguration';
            RebootNodeIfNeeded = $true;
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
            ActionAfterReboot = 'ContinueConfiguration';
            RebootNodeIfNeeded = $true;
        }
    }
}
LCMConfig
Set-DscLocalConfigurationManager LCMConfig -Force -Verbose

NameTimeIP -ConfigurationData $cd


Start-DscConfiguration NameTimeIP -Force -Wait -Verbose
