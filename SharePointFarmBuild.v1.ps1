<#

This DSC script takes the inputs under the param section and sets the IP address, default gateway, DNS server, disables IPv6, renames the server, updates the computer description, and sets the time zone to GMT and adds it to the DEV2.test doamin created with the ADDS script. It then installs SQL Server.
This example is allowing storage of credentials in plain text by setting PSDscAllowPlainTextPassword to $true.
Storing passwords in plain text is not a good practice and is presented only for simplicity and demonstration purposes.

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

<# Account Credentials #>
 
        $FarmAccount = Get-Credential -UserName 'dev2\SP.Farm' -Message "SP Farm Account and Password"
		
        $SPSetupAccount = Get-Credential -UserName 'dev2\SP.Setup' -Message "SP Setup Account and Password"

        $WebPoolManagedAccount = Get-Credential -UserName 'dev2\SP.WebPool' -Message "SP Webpool Account and Password"
   
        $ServicePoolManagedAccount = Get-Credential -UserName 'dev2\SP.ServicePool' -Message "SP ServicePool Account and Password"
        
        $Passphrase = Get-Credential -UserName 'dev2\administrator' -Message "SP Passphrase"
        
        $FileAccessAccount = Get-Credential -UserName 'dev2\administrator' -Message "File Share Account and Password"
   


Configuration SPInstall
{
    param 
	(
        
        [Parameter()]
        [String]
        $Name = 'SP1',
		
		[Parameter()]
        [String]
        $ComputerDescription = 'SharePoint Server',
		
		[Parameter()]
        [String]
        $IPAddress = '192.168.87.221',
		
		[Parameter()]
        [String]
        $DefaultGateway = '192.168.87.1',
		
		[Parameter()]
        [String]
        $DNS = '192.168.87.201',

<# Share Containing SharePoint2016 Binaries Extracted from ISO #>
		[Parameter()]
        [String]		
		$SP2016BinariesSource = '\\ADDS\SP2016Binaries',

<# Local Folder to Hold the SharePoint2016 Binaries #>
		[Parameter()]
        [String]		
		$SP2016BinariesDestination = 'C:\SP2016Binaries'


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
	
    node $AllNodes.NodeName
    {
 	
        File Started_File
        {
            DestinationPath = 'C:\Temp\Started.txt'
            Ensure = "Present"
            Contents = 'Computer not configured, not added to domain, and SharePoint not installed.'
        }

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

		PendingReboot PreJoinDomain
        {
            Name                        = 'PreJoinDomain'
            SkipComponentBasedServicing = $false
            SkipWindowsUpdate           = $false
            SkipPendingFileRename       = $false
            SkipPendingComputerRename   = $false
            SkipCcmClientSDK            = $false
            DependsOn                   = '[TimeZone]SetTimeZoneToGMT'
        }

		Computer JoinDomain
        {
            Name          	= $Name
            Description 	= $ComputerDescription
			DomainName 		= 'DEV2.TEST'
            Credential 		= $FileAccessAccount  # Credential to join to domain
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

         File SP2016Binaries_DirectoryCopy
        {
            Ensure                 = 'Present' # Ensure the directory is Present on the target node.
            Type                   = 'Directory' # The default is File.
            Recurse                = $true # Recursively copy all subdirectories.
            SourcePath             = $SP2016BinariesSource
            DestinationPath        = $SP2016BinariesDestination
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
            DependsOn                   = '[File]SP2016Binaries_DirectoryCopy'
        }
		
###############################################################################################
# SharePoint Prerequisites
###############################################################################################
        SPInstallPrereqs InstallPrereqs {
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
# Install SharePoint
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
		 				
		SPProductUpdate InstallKB4011244
		{
			SetupFile            = "\\adds\SP2016Binaries\updates\sts2016-kb4011244-fullfile-x64-glb.exe"
			ShutdownServices     = $true
			Ensure               = "Present"
			PsDscRunAsCredential = $SPSetupAccount
		}

		SPConfigWizard RunConfigWizard
		{
			IsSingleInstance     	= "Yes"
			Ensure					= 'Present'
			PsDscRunAsCredential 	= $SPSetupAccount
            DependsOn               = '[SPProductUpdate]InstallKB4011244'			
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

		PendingReboot PostInstallKB4011244
        {
            Name                        = 'PostInstallKB4011244'
            SkipComponentBasedServicing = $false
            SkipWindowsUpdate           = $false
            SkipPendingFileRename       = $false
            SkipPendingComputerRename   = $false
            SkipCcmClientSDK            = $false
            DependsOn                   = '[PendingReboot]InstallKB4011244'
        }		

        #**********************************************************
        # Basic farm configuration
        #
        # This section creates the new SharePoint farm object, and
        # provisions generic services and components used by the
        # whole farm
        #**********************************************************
        		
        SPFarm CreateSPFarm
        {
            IsSingleInstance         = "Yes"
            Ensure                   = "Present"
            DatabaseServer           = "sql.dev2.test"
            FarmConfigDatabaseName   = "SP_Config"
            Passphrase               = $Passphrase
            FarmAccount              = $FarmAccount
            PsDscRunAsCredential     = $SPSetupAccount
            AdminContentDatabaseName = "SP_AdminContent"
            RunCentralAdmin          = $true
            DependsOn                = "[SPInstall]InstallSharePoint"
        }

        SPManagedAccount ServicePoolManagedAccount
        {
            AccountName          = $ServicePoolManagedAccount.UserName
            Account              = $ServicePoolManagedAccount
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPManagedAccount WebPoolManagedAccount
        {
            AccountName          = $WebPoolManagedAccount.UserName
            Account              = $WebPoolManagedAccount
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPDiagnosticLoggingSettings ApplyDiagnosticLogSettings
        {
            IsSingleInstance                            = "Yes"
            PsDscRunAsCredential                        = $SPSetupAccount
            LogPath                                     = "C:\ULS"
            LogSpaceInGB                                = 5
            AppAnalyticsAutomaticUploadEnabled          = $false
            CustomerExperienceImprovementProgramEnabled = $true
            DaysToKeepLogs                              = 7
            DownloadErrorReportingUpdatesEnabled        = $false
            ErrorReportingAutomaticUploadEnabled        = $false
            ErrorReportingEnabled                       = $false
            EventLogFloodProtectionEnabled              = $true
            EventLogFloodProtectionNotifyInterval       = 5
            EventLogFloodProtectionQuietPeriod          = 2
            EventLogFloodProtectionThreshold            = 5
            EventLogFloodProtectionTriggerPeriod        = 2
            LogCutInterval                              = 15
            LogMaxDiskSpaceUsageEnabled                 = $true
            ScriptErrorReportingDelay                   = 30
            ScriptErrorReportingEnabled                 = $true
            ScriptErrorReportingRequireAuth             = $true
            DependsOn                                   = "[SPFarm]CreateSPFarm"
        }

        SPUsageApplication UsageApplication
        {
            Name                  = "Usage Service Application"
            DatabaseName          = "SP_Usage"
            UsageLogCutTime       = 5
            UsageLogLocation      = "C:\UsageLogs"
            UsageLogMaxFileSizeKB = 1024
            PsDscRunAsCredential  = $SPSetupAccount
            DependsOn             = "[SPFarm]CreateSPFarm"
        }

        SPStateServiceApp StateServiceApp
        {
            Name                 = "State Service Application"
            DatabaseName         = "SP_State"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPDistributedCacheService EnableDistributedCache
        {
            Name                 = "AppFabricCachingService"
            Ensure               = "Present"
            CacheSizeInMB        = 1024
            ServiceAccount       = $ServicePoolManagedAccount.UserName
            PsDscRunAsCredential = $SPSetupAccount
            CreateFirewallRules  = $true
            DependsOn            = @('[SPFarm]CreateSPFarm','[SPManagedAccount]ServicePoolManagedAccount')
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
        # Web applications
        #
        # This section creates the web applications in the
        # SharePoint farm, as well as managed paths and other web
        # application settings
        #**********************************************************

        SPWebApplication SharePointSites
        {
            Name                   = "SharePoint Sites"
            ApplicationPool        = "SharePoint Sites"
            ApplicationPoolAccount = $WebPoolManagedAccount.UserName
            AllowAnonymous         = $false
            DatabaseName           = "SP_Content"
            WebAppUrl              = "http://sites.dev2.test"
            HostHeader             = "sites.dev2.test"
            Port                   = 80
            PsDscRunAsCredential   = $SPSetupAccount
            DependsOn              = "[SPManagedAccount]WebPoolManagedAccount"
        }

        SPCacheAccounts WebAppCacheAccounts
        {
            WebAppUrl              = "http://sites.dev2.test"
            SuperUserAlias         = "dev2\sp.farm"
            SuperReaderAlias       = "dev2\sp.farm"
            PsDscRunAsCredential   = $SPSetupAccount
            DependsOn              = "[SPWebApplication]SharePointSites"
        }

        SPSite TeamSite
        {
            Url                      = "http://sites.dev2.test"
            OwnerAlias               = "dev2\sp.farm"
            Name                     = "DSC Demo Site"
            Template                 = "STS#0"
            PsDscRunAsCredential     = $SPSetupAccount
            DependsOn                = "[SPWebApplication]SharePointSites"
        }

		PendingReboot TeamSite
        {
            Name                        = 'TeamSite'
            SkipComponentBasedServicing = $false
            SkipWindowsUpdate           = $false
            SkipPendingFileRename       = $false
            SkipPendingComputerRename   = $false
            SkipCcmClientSDK            = $false
            DependsOn                   = '[SPSite]TeamSite'
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
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPServiceInstance SecureStoreServiceInstance
        {
            Name                 = "Secure Store Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPServiceInstance ManagedMetadataServiceInstance
        {
            Name                 = "Managed Metadata Web Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPServiceInstance BCSServiceInstance
        {
            Name                 = "Business Data Connectivity Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPServiceInstance SearchServiceInstance
        {
            Name                 = "SharePoint Server Search"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

		PendingReboot SearchServiceInstance
        {
            Name                        = 'SearchServiceInstance'
            SkipComponentBasedServicing = $false
            SkipWindowsUpdate           = $false
            SkipPendingFileRename       = $false
            SkipPendingComputerRename   = $false
            SkipCcmClientSDK            = $false
            DependsOn                   = '[SPServiceInstance]SearchServiceInstance'
        }
	
        #**********************************************************
        # Service applications
        #
        # This section creates service applications and required
        # dependencies
        #**********************************************************

        $serviceAppPoolName = "SharePoint Service Applications"
        SPServiceAppPool MainServiceAppPool
        {
            Name                 = $serviceAppPoolName
            ServiceAccount       = $ServicePoolManagedAccount.UserName
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPSecureStoreServiceApp SecureStoreServiceApp
        {
            Name                  = "Secure Store Service Application"
            ApplicationPool       = $serviceAppPoolName
            AuditingEnabled       = $true
            AuditlogMaxSize       = 30
            DatabaseName          = "SP_SecureStore"
            PsDscRunAsCredential  = $SPSetupAccount
            DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
        }

        SPManagedMetaDataServiceApp ManagedMetadataServiceApp
        {
            Name                 = "Managed Metadata Service Application"
            PsDscRunAsCredential = $SPSetupAccount
            ApplicationPool      = $serviceAppPoolName
            DatabaseName         = "SP_MMS"
            DependsOn            = "[SPServiceAppPool]MainServiceAppPool"
        }

        SPBCSServiceApp BCSServiceApp
        {
            Name                  = "BCS Service Application"
            ApplicationPool       = $serviceAppPoolName
            DatabaseName          = "SP_BCS"
			DatabaseServer		  = 'sql.dev2.test'
            PsDscRunAsCredential  = $SPSetupAccount
            DependsOn             = @('[SPServiceAppPool]MainServiceAppPool', '[SPSecureStoreServiceApp]SecureStoreServiceApp')
        }

        SPSearchServiceApp SearchServiceApp
        {
            Name                  = "Search Service Application"
            DatabaseName          = "SP_Search"
            ApplicationPool       = $serviceAppPoolName
            PsDscRunAsCredential  = $SPSetupAccount
            DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
        }

		PendingReboot SearchServiceApp
        {
            Name                        = 'SearchServiceApp'
            SkipComponentBasedServicing = $false
            SkipWindowsUpdate           = $false
            SkipPendingFileRename       = $false
            SkipPendingComputerRename   = $false
            SkipCcmClientSDK            = $false
            DependsOn                   = '[SPSearchServiceApp]SearchServiceApp'
        }


        File Finished_File
        {
            DestinationPath = 'C:\Temp\Finished.txt'
            Ensure = "Present"
            Contents = 'Computer configured, added to domain, and SharePoint installed.'
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

SPInstall -ConfigurationData $cd

Start-DscConfiguration SPInstall -Force -Wait -Verbose
