# This script was intended for Dynamics CRM 2016 on-premise.

function Get-Users {
<#
.SYNOPSIS
	Retrieve dynamics system users domain name.
.DESCRIPTION
	Retrieve dynamics system users domain name.
.PARAMETER ServerUrl
	The server url and the organization
.EXAMPLE
	Get-Users -ServerUrl "http://yourcrmserver/CRM"
.NOTES
	Nicolas Plourde
	www.xrmmtl.com
	github.com/nickpl
	1.0 | 2018/07/26 | Nicolas Plourde
		Initial Version
#>
    param(
		[string]$serverurl
	)
	$headers = @{
		"Accept"="application/json";
		"Content-Type"="application/json; charset=utf-8";
		"OData-MaxVersion"="4.0";
		"OData-Version"="4.0";
	};

	$users = Invoke-WebRequest -Uri "$serverurl/api/data/v8.2/systemusers/?`$select=domainname&`$filter=isdisabled eq false and domainname ne ''" -Method GET -Headers $headers -UseDefaultCredentials -UseBasicParsing;
	return (ConvertFrom-Json $users.Content).value;
}

function Get-Adinfo {
<#
.SYNOPSIS
	Retrieve Active Directory information from Dynamics webservice using domain name
.DESCRIPTION
	Retrieve Active Directory information from Dynamics webservice using a system user containing the domain name
.PARAMETER ServerUrl
	The server url and the organization
.EXAMPLE
	Get-Adinfo -user @{domainname:'domain\username'} -ServerUrl "http://yourcrmserver/CRM"
.EXAMPLE
	Get-Users -ServerUrl "http://yourcrmserver/CRM" | foreach { Get-Adinfo $_ -ServerUrl "http://yourcrmserver/CRM" } 
.NOTES
	Nicolas Plourde
	www.xrmmtl.com
	github.com/nickpl
	1.0 | 2018/07/26 | Nicolas Plourde
		Initial Version
#>
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline)]
		$user,
        [string]$serverurl
	)

$ad_request = 
@"
<?xml version="1.0" encoding="utf-8" ?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
	<soap:Body>
		<RetrieveADUserProperties xmlns="http://schemas.microsoft.com/crm/2009/WebServices">
			<domainAccountName>{0}</domainAccountName>
		</RetrieveADUserProperties>
	</soap:Body>
</soap:Envelope>
"@;

	$userManagerEndPoint = "$serverurl/AppWebServices/UserManager.asmx";

	$domainName = $user.domainname;
	$request = $ad_request.Replace("{0}", $domainName);

	$headers = @{
		"Accept"="application/xml, text/xml, */*";
		"Content-Type"="text/xml; charset=utf-8";
		"SOAPAction"="http://schemas.microsoft.com/crm/2009/WebServices/RetrieveADUserProperties";
	};

	$adinfo = Invoke-WebRequest -Uri $userManagerEndPoint -Method POST -Headers $headers -Body $request -UseDefaultCredential -UseBasicParsing;

	[xml]$xml = $adinfo.Content;
	[xml]$xmlContent = $xml.GetElementsByTagName('RetrieveADUserPropertiesResult').'#text';

	if($xmlContent -eq $null)
	{ 
		Write-Warning "Nothing found for $domainName. Check if the user is still in the Active Directory";
		return $null;
	}

	return @{
		"crminfo"=$user;
		"adinfo"=$xmlContent.GetElementsByTagName('systemuser');
	};
}

function Set-User {
<#
.SYNOPSIS
	Update Dynamics system user informations using an object coming from UserManager webservice
.DESCRIPTION
	Update Dynamics system user informations using an object coming from UserManager webservice
.PARAMETER Infos
	An object containing both information from the user in Dynamics and from Active Directory. See Get-Adinfo.
.PARAMETER ServerUrl
	The server url and the organization
.EXAMPLE
	Get-Users -ServerUrl "http://yourcrmserver/CRM" | foreach { Get-Adinfo $_ -ServerUrl "http://yourcrmserver/CRM" | Set-User -ServerUrl $serverUrl "http://yourcrmserver/CRM" } 
.NOTES
	Nicolas Plourde
	www.xrmmtl.com
	github.com/nickpl
	1.0 | 2018/07/26 | Nicolas Plourde
		Initial Version
#>
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline)]
		$infos,
        [string]$serverurl
	)

	if($infos -eq $null)
	{ return; }

	try
	{
		$userid = $infos.crminfo.systemuserid;
		$fullname = $infos.adinfo[0] | select firstname, lastname, domainname;
		# I excluded internalemailaddress because it was unapproving the email addresses.
		$adjson = $infos.adinfo[0] | select title,firstname,lastname,address1_telephone1,address1_telephone3,address1_fax,homephone,mobilephone,address1_postofficebox,address1_line1,address1_city,address1_postalcode,address1_stateorprovince,domainname | ConvertTo-Json -Compress
		
		$adjson = [System.Text.Encoding]::UTF8.GetBytes($adjson);

		$headers = @{
			"Content-Type"="application/json; charset=utf-8";
			"OData-MaxVersion"="4.0";
			"OData-Version"="4.0";
		};
		$result = Invoke-WebRequest -Uri "$serverurl/api/data/v8.2/systemusers($userid)" -Method PATCH -Headers $headers -Body $adjson -UseDefaultCredentials -UseBasicParsing;
		$code = $result.StatusCode;

		if($result.StatusCode -eq 204) {
			Write-Host "Status Code: $code, Id: $userid, Name: $fullname";
		}
		else {
			Write-Error "Status Code: $code, Id: $userid, Name: $fullname";
		}
	}
	catch
	{
		$error = $_.Exception.Message;
		Write-Error "ERROR, Id: $userid, Info: $adjson, Message: $error";
	}   
}

$serverUrl = "http://yourcrmserver/CRM";
Get-Users -ServerUrl $serverUrl | foreach { Get-Adinfo $_ -ServerUrl $serverUrl | Set-User -ServerUrl $serverUrl } 
