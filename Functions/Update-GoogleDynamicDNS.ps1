Function Update-GoogleDynamicDNS
{
<#
.SYNOPSIS
Sends a HTTPS POST request to the Google domain service to update a dynamic DNS entry

.DESCRIPTION
This function will send a POST request to the Google domains HTTPS API and set the active IP for a hostname on a given DNS entry. It accomplishes this via a Invoke-WebRequest to a URI and passes in parameters that are set by the user. This function will return an object containing the completed equest fromthe HTTPS POST. For detailed messages on successful requests, you can use the -Verbose switch.

.PARAMETER Credential
A PSCredential object containing your Dynamic DNS generated credentials from Google.

.PARAMETER GeneratedPassword
If you don't want to use a PSCredential object and instead pass in the Password in the clear, you can use this parameter.

.PARAMETER DomainName
The top-level DNS record you want to update in Google's DNS records.
	
.PARAMETER SubDomainName
The subdomain you want to set the IP address for in Google's DNS records for the top-level domain.

.PARAMETER ip
The IP you want to set the subdomain's IP address to. This is an optional parameter. If no ip is supplied, Google will set your IP to the host's public IP that sent the request.

.PARAMETER Offline
This switch will set your dynamic DNS record to be set offline by Google.

.PARAMETER Online
This switch will set your dynamic DNS record to be set online by Google.
	
.PARAMETER WhatIf
Shows what would happen if the command was executed	
	
.NOTES 
Author: Drew Furgiuele (@pittfurg), http://www.port1433.com

This was written to support the API documentation outlined here: https://support.google.com/domains/answer/6147083?hl=en

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

.EXAMPLE
Update-GoogleDynamicDNS.ps1 -Credential $Credential -domainName yourdomain.com -subdomainName www
Sends a HTTPS POST request to the Google dynamic DNS API using a PSCredential object to set the subdomain 'www' (www.yourdomain.com) to the public IP of the host sending the request

Update-GoogleDynamicDNS.ps1 -Credential $Credential -domainName yourdomain.com -subdomainName www -IP 1.1.1.1
Sends a HTTPS POST request to the Google dynamic DNS API using a PSCredential object to set the subdomain 'www' (www.yourdomain.com) to 1.1.1.1

Update-GoogleDynamicDNS.ps1 -Credential $Credential -domainName yourdomain.com -subdomainName www -Offline
Sends a HTTPS POST request to the Google dynamic DNS API using a PSCredential object to set the subdomain 'www' offline

Update-GoogleDynamicDNS.ps1 -Credential $Credential -domainName yourdomain.com -subdomainName www -Online
Sends a HTTPS POST request to the Google dynamic DNS API using a PSCredential object to set the subdomain 'www' online

#>
  
    [CmdletBinding(SupportsShouldProcess = $true)]
	Param (
        [parameter(Mandatory=$true)] 
        [pscredential] $credential,
		[parameter(Mandatory = $true)]
		[string]$domainName,
		[parameter(Mandatory = $true)]
		[string]$subdomainName,
		[parameter(Mandatory = $false)]
		[string]$ip,
		[parameter(Mandatory = $false)]
		[switch]$offline,
		[parameter(Mandatory = $false)]
		[switch]$online
	)

    begin {
        $webRequestURI = "https://domains.google.com/nic/update"
        $params = @{}
    }

    process {
        $splitDomain = $domainName.split(".")
        if ($splitDomain.Length -ne 2) {
            Throw "Please enter a valid top-level domain name (yourdomain.tld)"
        }
        $subAndDomain = $subDomainName + "." + $domainName
        $splitDomain = $subAndDomain.split(".")
        if ($splitDomain.Length -ne 3) {
            Throw "Please enter a valid host and domain name (subdomain.yourdomain.tld)"
        }

        $params.Add("hostname",$subAndDomain)


        if ($ip -and !$offline) {
            $ipValid = $true
            $splitIp = $ip.split(".")
            if ($splitIp.length -ne 4) {
                $ipValid = $false
            }
            ForEach ($i in $splitIp) {
                if ([int] $i -lt 0 -or [int] $i -gt 255) {
                    $ipValid = $false
                }
            }
            if (!$ipValid) {
                Throw "Please enter a valid IP address"
            }
            $params.Add("myip",$ip)
        } elseif ($offline -and !$online) {
            $params.Add("offline","yes")
        } elseif ($online -and !$offline) {
            $params.Add("offline","no")
        }

        if ($PSCmdlet.ShouldProcess("$subAndDomain","Adding IP"))
        {
            $response = Invoke-WebRequest -uri $webRequestURI -Method Post -Body $params -Credential $credential 
            $Result = $Response.Content
            $StatusCode = $Response.StatusCode
            
            if ($Result -like "good*") {
                $splitResult = $Result.split(" ")
                $newIp = $splitResult[1]
                Write-Verbose "IP successfully updated for $subAndDomain to $newIp."
            }
            if ($Result -like "nochg*") {
                $splitResult = $Result.split(" ")
                $newIp = $splitResult[1]
                Write-Verbose "No change to IP for $subAndDomain (already set to $newIp)."
            }
            if ($Result -eq "badauth") {
                Throw "The username/password you providede was not valid for the specified host."
            }
            if ($Result -eq "nohost") {
                Throw "The hostname you provided does not exist, or dynamic DNS is not enabled."
            }
            if ($Result -eq "notfqdn") {
                Throw "The supplied hostname is not a valid fully-qualified domain name."
            }
            if ($Result -eq "badagent") {
                Throw "You are making bad agent requests, or are making a request with IPV6 address (not supported)."
            }
            if ($Result -eq "abuse") {
                Throw "Dynamic DNS access for the hostname has been blocked due to failure to interperet previous responses correctly."
            }
            if ($Result -eq "911") {
                Throw "An error happened on Google's end; wait 5 minutes and try again."
            }
        }
        $response
    }
}
    
