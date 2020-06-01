<#
    .EXAMPLE
    Text Goes Here

#>

Set-ExecutionPolicy -ExecutionPolicy Unrestricted

cd C:\TEMP

<# Determine Name of the Network Adapter in this OS #>
	$NetAdapterName = Get-NetAdapter -Name "Ethernet*"
	$NetAdapterName = $NetAdapterName.ifAlias

    $Credential = Get-Credential -UserName 'administrator' -Message "New Domain Admin User Name and Password"

Configuration NameTimeIP
{

########################################################
# Account Credential and Variable Region
########################################################

    param
    (
	
<# Computer Variables #>

<# Server Name #>	
        [Parameter()]
        [String]
        $Name = 'PowerSTIG',

<# Server Description #>		
		[Parameter()]
        [String]
        $ComputerDescription = 'PowerSTIG Station',

<# Server IP Address #>			
 		[Parameter()]
        [String]
        $IPAddress = '192.168.87.220',

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
            TimeZone         	= 'GMT Standard Time'
			DependsOn	   		= '[DefaultGatewayAddress]SetDefaultGateway'
        }

		Computer JoinDomain
        {
            Name          	= $Name
            Description 	= $ComputerDescription
			DomainName 		= $DomainFQDN
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
