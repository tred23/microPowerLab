<#
    .EXAMPLE
    Text Goes Here

#>

Set-ExecutionPolicy -ExecutionPolicy Unrestricted

# directory where the DSC scripts are located
cd c:\temp


Configuration NameTimeIP
{
    param
    (
        [Parameter()]
        [String]
        $Name = 'SP2',
		
		[Parameter()]
        [String]
        $ComputerDescription = 'SharePoint Server',
		
		[Parameter()]
        [String]
        $IPAddress = '192.168.87.222',
		
		[Parameter()]
        [String]
        $DefaultGateway = '192.168.87.1',
		
		[Parameter()]
        [String]
        $DNS = '192.168.87.201',
		
	    [Parameter(Mandatory=$true)] 
		[ValidateNotNullorEmpty()] 
		[PSCredential] 
		$FarmAccount, #"dev2\SP.Farm"
		
        [Parameter(Mandatory=$true)] 
		[ValidateNotNullorEmpty()] 
		[PSCredential] 
		$SPSetupAccount, #"dev2\SP.Setup"
		
        [Parameter(Mandatory=$true)] 
		[ValidateNotNullorEmpty()] 
		[PSCredential] 
		$WebPoolManagedAccount, #"dev2\SP.WebPool"
		
        [Parameter(Mandatory=$true)] 
		[ValidateNotNullorEmpty()] 
		[PSCredential] 
		$ServicePoolManagedAccount, #"dev2\SP.ServicePool"
		
        [Parameter(Mandatory=$true)] 
		[ValidateNotNullorEmpty()] 
		[PSCredential] 
		$Passphrase,
		
        [Parameter(Mandatory=$true)] 
		[ValidateNotNullorEmpty()] 
		[PSCredential] 
		$FileAccessAccount
    )

########################################################
# DSC Module Region
########################################################

    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module NetworkingDsc
	Import-DscResource -Module ComputerManagementDsc
	Import-DscResource -Module xNetworking
    Import-DscResource -ModuleName SharePointDsc
	
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
            Name          	= $Name
            Description 	= $ComputerDescription
			DomainName 		= 'DEV2.TEST'
            Credential 		= $Passphrase  # Credential to join to domain
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

########################################################
# SharePoint Region
########################################################

###############################################################################################
# Add Domain Users to Local Admin Group
###############################################################################################

		Group AddADUserToLocalAdminGroup 
		{
			GroupName='Administrators'
			Ensure= 'Present'
			MembersToInclude= "dev2\SharePointAccounts"
			PsDscRunAsCredential = $FileAccessAccount
		}
						
###############################################################################################
# Copy SharePoint Binaries
###############################################################################################

        File 'DirectoryCopy'
        {
            Ensure = "Present" # Ensure the directory is Present on the target node.
            Type = "Directory" # The default is File.
            Recurse = $true # Recursively copy all subdirectories.
            SourcePath = "\\ADDS\SP2016Binaries"
            DestinationPath = "C:\SP2016Binaries"
			PsDscRunAsCredential   = $FileAccessAccount
        }
		        		
		PendingReboot DirectoryCopy
        {
            Name                        = 'DirectoryCopy'
            SkipComponentBasedServicing = $false
            SkipWindowsUpdate           = $false
            SkipPendingFileRename       = $false
            SkipPendingComputerRename   = $false
            SkipCcmClientSDK            = $false
            DependsOn                   = '[File]DirectoryCopy'
        }
		
		
###############################################################################################
# Install SharePoint Prerequisites
###############################################################################################
        SPInstallPrereqs InstallPrereqs 
		{
            IsSingleInstance  = "Yes"
            Ensure            = "Present"
            InstallerPath     = "C:\SP2016Binaries\prerequisiteinstaller.exe"
            OnlineMode        = $true
        }
		        		
		PendingReboot InstallPrereqs
        {
            Name                        = 'InstallPrereqs'
            SkipComponentBasedServicing = $false
            SkipWindowsUpdate           = $false
            SkipPendingFileRename       = $false
            SkipPendingComputerRename   = $false
            SkipCcmClientSDK            = $false
            DependsOn                   = '[SPInstallPrereqs]InstallPrereqs'
        }
		
###############################################################################################
# Install SharePoint Binaries
###############################################################################################	
	
        SPInstall InstallSharePoint 
        {
            IsSingleInstance  = "Yes"
            Ensure            = "Present"
            BinaryDir         = "C:\SP2016Binaries\"
            ProductKey        = "NQGJR-63HC8-XCRQH-MYVCH-3J3QR"
            DependsOn         = "[SPInstallPrereqs]InstallPrereqs"
        }

		PendingReboot InstallSharePoint
        {
            Name                        = 'InstallSharePoint'
            SkipComponentBasedServicing = $false
            SkipWindowsUpdate           = $false
            SkipPendingFileRename       = $false
            SkipPendingComputerRename   = $false
            SkipCcmClientSDK            = $false
            DependsOn                   = '[SPInstall]InstallSharePoint'
        }
		
###############################################################################################
# Install SharePoint Updates and/or Patches
###############################################################################################	

		SPProductUpdate InstallKB4011244
		{
			SetupFile            = "\\adds\SP2016Binaries\updates\sts2016-kb4011244-fullfile-x64-glb.exe"
			ShutdownServices     = $true
			Ensure               = "Present"
			PsDscRunAsCredential = $SPSetupAccount
		}

		PendingReboot InstallKB4011244
        {
            Name                        = 'InstallKB4011244'
            SkipComponentBasedServicing = $false
            SkipWindowsUpdate           = $false
            SkipPendingFileRename       = $false
            SkipPendingComputerRename   = $false
            SkipCcmClientSDK            = $false
            DependsOn                   = '[SPProductUpdate]InstallKB4011244'
        }
		 		
        #**********************************************************
        # Basic farm configuration
        #
        # This section creates the new SharePoint farm object, and
        # provisions generic services and components used by the
        # whole farm
        #**********************************************************
		
        SPFarm JoinSPFarm
        {
            IsSingleInstance         = "Yes"
            Ensure                   = "Present"
            DatabaseServer           = "sql.dev2.test"
            FarmConfigDatabaseName   = "SP_Config"
            Passphrase               = $Passphrase
            FarmAccount              = $FarmAccount
            PsDscRunAsCredential     = $SPSetupAccount
            AdminContentDatabaseName = "SP_AdminContent"
            RunCentralAdmin          = $false
            DependsOn                = "[SPInstall]InstallSharePoint"
        }

		PendingReboot JoinSPFarm
        {
            Name                        = 'JoinSPFarm'
            SkipComponentBasedServicing = $false
            SkipWindowsUpdate           = $false
            SkipPendingFileRename       = $false
            SkipPendingComputerRename   = $false
            SkipCcmClientSDK            = $false
            DependsOn                   = '[SPFarm]JoinSPFarm'
        }
		 
        SPDistributedCacheService EnableDistributedCache
        {
            Name                 = "AppFabricCachingService"
            Ensure               = "Present"
            CacheSizeInMB        = 1024
            ServiceAccount       = $ServicePoolManagedAccount.UserName
            PsDscRunAsCredential = $SPSetupAccount
            CreateFirewallRules  = $true
            DependsOn            = "[SPFarm]JoinSPFarm"
        }

		PendingReboot EnableDistributedCache
        {
            Name                        = 'EnableDistributedCache'
            SkipComponentBasedServicing = $false
            SkipWindowsUpdate           = $false
            SkipPendingFileRename       = $false
            SkipPendingComputerRename   = $false
            SkipCcmClientSDK            = $false
            DependsOn                   = '[SPDistributedCacheService]EnableDistributedCache'
        }
		 
        #**********************************************************
        # Service instances
        #
        # This section describes which services should be running
        # and not running on the server
        #**********************************************************

        SPServiceInstance ClaimsToWindowsTokenServiceInstance
        {
            Name                 = "Claims to Windows Token Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]JoinSPFarm"
        }

        SPServiceInstance ManagedMetadataServiceInstance
        {
            Name                 = "Managed Metadata Web Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]JoinSPFarm"
        }

        SPServiceInstance BCSServiceInstance
        {
            Name                 = "Business Data Connectivity Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]JoinSPFarm"
        }

		PendingReboot BCSServiceInstance
        {
            Name                        = 'BCSServiceInstance'
            SkipComponentBasedServicing = $false
            SkipWindowsUpdate           = $false
            SkipPendingFileRename       = $false
            SkipPendingComputerRename   = $false
            SkipCcmClientSDK            = $false
            DependsOn                   = '[SPServiceInstance]BCSServiceInstance'
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