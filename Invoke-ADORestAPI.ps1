﻿function Invoke-ADORestAPI
{
    <#
    .Synopsis
        Uses the ADO Rest API
    .Description
        Uses the Azure DevOps REST API
    .Example
        # Uses the Azure DevOps REST api to get builds from a project
        $org = 'StartAutomating'
        $project = 'PSDevOps'
        Invoke-ADORestAPI "https://dev.azure.com/$org/$project/_apis/build/builds/?api-version=5.1"
    .Link
        Invoke-RestMethod
    #>
    param(
    # The REST API Url
    [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
    [Alias('Url')]
    [uri]
    $Uri,

    # A Personal Access Token
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('PAT')]
    [string]
    $PersonalAccessToken,

    <#
Specifies the method used for the web request. The acceptable values for this parameter are:
 - Default
 - Delete
 - Get
 - Head
 - Merge
 - Options
 - Patch
 - Post
 - Put
 - Trace
    #>
    [Parameter(ValueFromPipelineByPropertyName)]
    [ValidateSet('GET','DELETE','HEAD','MERGE','OPTIONS','PATCH','POST', 'PUT', 'TRACE')]
    [string]
    $Method,

    # Specifies the body of the request.
    # If this value is a string, it will be passed as-is
    # Otherwise, this value will be converted into JSON.
    [Parameter(ValueFromPipelineByPropertyName)]
    [Object]
    $Body,

    # Specifies the content type of the web request.
    # If this parameter is omitted and the request method is POST, Invoke-RestMethod sets the content type to application/x-www-form-urlencoded. Otherwise, the content type is not specified in the call.
    [string]
    $ContentType = 'application/json',

    # Specifies the headers of the web request. Enter a hash table or dictionary.
    [System.Collections.IDictionary]
    [Alias('Header')]
    $Headers,

    # Specifies a user account that has permission to send the request. The default is the current user.
    # Type a user name, such as User01 or Domain01\User01, or enter a PSCredential object, such as one generated by the Get-Credential cmdlet.
    [pscredential]
    [Management.Automation.CredentialAttribute()]
    $Credential,

    # Indicates that the cmdlet uses the credentials of the current user to send the web request.
    [Alias('UseDefaultCredential')]
    [switch]
    $UseDefaultCredentials,

    # Specifies that the cmdlet uses a proxy server for the request, rather than connecting directly to the Internet resource. Enter the URI of a network proxy server.
    [uri]
    $Proxy,

    # Specifies a user account that has permission to use the proxy server that is specified by the Proxy parameter. The default is the current user.
    # Type a user name, such as "User01" or "Domain01\User01", or enter a PSCredential object, such as one generated by the Get-Credential cmdlet.
    # This parameter is valid only when the Proxy parameter is also used in the command. You cannot use the ProxyCredential and ProxyUseDefaultCredentials parameters in the same command.
    [pscredential]
    [Management.Automation.CredentialAttribute()]
    $ProxyCredential,

    # Indicates that the cmdlet uses the credentials of the current user to access the proxy server that is specified by the Proxy parameter.
    # This parameter is valid only when the Proxy parameter is also used in the command. You cannot use the ProxyCredential and ProxyUseDefaultCredentials parameters in the same command.
    [switch]
    $ProxyUseDefaultCredentials,

    # The typename of the results.
    [Parameter(ValueFromPipelineByPropertyName)]
    [string[]]
    $PSTypeName)

    process {
        #region Prepare Parameters
        $irmSplat = @{} + $PSBoundParameters    # First, copy PSBoundParameters and remove the parameters that aren't Invoke-RestMethod's
        $irmSplat.Remove('PersonalAccessToken') # * -PersonalAccessToken
        $irmSplat.Remove('PSTypeName') # * -PSTypeName

        if ($PersonalAccessToken) { # If there was a personal access token, set the authorization header
            if ($Headers) { # (make sure not to step on other headers).
                $irmSplat.Headers.Authorization = "Basic $([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(":$PersonalAccessToken")))"
            }
            else {

                $irmSplat.Headers = @{ # If you were wondering, the Personal Access Token is passed like an HTTP credential,
                    Authorization = # (by setting the authorization header to Basic Base64EncodedBytesOf UserName:Password).
                        # The very slight trick is that PersonalAccessToken's don't have a username
                        "Basic $([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(":$PersonalAccessToken")))"
                }
            }
        }
        if ($Body -and $Body -isnot [string]) { # If a body was passed, and it wasn't a string
            $irmSplat.Body = $Body | ConvertTo-Json -Depth 100 # make it JSON.
        }
        if (-not $irmSplat.ContentType) { # If no content type was passed
            $irmSplat.ContentType = $ContentType # set it to the default.
        }
        #endregion Prepare Parameters

        #region Call Invoke-RestMethod

        # We call Invoke-RestMethod with the parameters we've passed in.
        # It will take care of converting the results from JSON.
        Invoke-RestMethod @irmSplat |
            & { process {
                # What it will not do is "unroll" them.
                # A lot of things in the Azure DevOps REST apis come back as a count/value pair
                if ($_.Value -and $_.Count) {  # If that's what we're dealing with
                    $_.Value # pass value down the pipe.
                } elseif ($_ -notlike '*<html*') { # Otherise, As long as the value doesn't look like HTML,
                    $_ # pass it down the pipe.
                } else { # If it happened to look like HTML, write an error
                    Write-Error "Response was HTML, Request Failed.  Use -Verbose to see the full response"
                    Write-Verbose "$_" # and write the full content to verbose.
                    return
                }
            } } |
            & { process { # One more step of the pipeline will unroll each of the values.
                if ($PSTypeName) { # If we have a PSTypeName (to apply formatting)
                    $_.PSTypeNames.Clear() # clear the existing typenames and decorate the object.
                    foreach ($t in $PSTypeName) {
                        $_.PSTypeNames.add($T)
                    }
                }
                return $_ # output the object and we're done.
            } }
        #endregion Call Invoke-RestMethod
    }
}