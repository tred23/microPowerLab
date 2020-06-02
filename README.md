# microPowerLab
PowerShellDSC Scripts to setup a small lab environment for testing puposes.


First create the Domain Controller<br>
Next create the SQL server<br>
Finally create the first SharePoint server in the farm and add more SharePoint server to the farm if you want.<br>

You will need the following PowerShell DSC Modules:<br>

ActiveDirectoryDsc<br> https://github.com/dsccommunity/ActiveDirectoryDsc<br>
ComputerManagementDsc<br> https://github.com/dsccommunity/ComputerManagementDsc<br>
NetworkingDsc<br> https://github.com/dsccommunity/NetworkingDsc<br>
SharePointDsc<br> https://github.com/dsccommunity/SharePointDsc<br>
SqlServerDsc<br> https://github.com/dsccommunity/SqlServerDsc<br>
xDnsServer<br> https://github.com/dsccommunity/xDnsServer<br>

You will need a virtual machine image that is just Windows OS with the latest patches/updates for each role.<br>

You will need to the extracted ISO files for SQL and SharePoint in a share on the Domain Controller. Yes I know you are not supposed to use your Domain Controller as a file share but this project is for setting a very small lab for testing only.<br>

You will also need all the prerequisites for SharePoint in a share on the Domain Controller as well.

You will need to copy the above PowerShell DSC modules in the C:\Program Files\WindowsPowerShell\Modules before you run the scripts.

Yes you will need to run Set-ExecutionPolicy -ExecutionPolicy Unrestricted before you run the scripts.

If you have questions please ask or open an issue.
