# This PowerShell script connects to Apple Lookup Uri and reads the latest version of iOS available for Intune-onboarded devices. The lowest version available for all devices is then set as the minimum requirement in the Intune compliance policy.
param(
    [Parameter(Mandatory = $true)]
    [string] $PolicyDisplayName,

    [Parameter(Mandatory = $false)]
    [bool] $DryRun = $true,

    [Parameter(Mandatory = $false)]
    [int] $MaxMajorJump = 1
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$AppleLookupUri   = "https://gdmf.apple.com/v2/pmv"
$GraphBaseUri     = "https://graph.microsoft.com/v1.0"
$GraphBetaBaseUri = "https://graph.microsoft.com/beta"

#
# Basic parameter validation
#

if ([string]::IsNullOrWhiteSpace($PolicyDisplayName)) {
    throw "PolicyDisplayName cannot be empty."
}

if ($MaxMajorJump -lt 0) {
    throw "MaxMajorJump cannot be negative."
}

#
# Apple certificate handling
#

function Get-VerifiedAppleRootCertificate {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Uri,

        [Parameter(Mandatory = $true)]
        [string] $ExpectedSHA256
    )

    $httpClient = [System.Net.Http.HttpClient]::new()

    try {
        $bytes = $httpClient.GetByteArrayAsync($Uri).GetAwaiter().GetResult()
    }
    finally {
        $httpClient.Dispose()
    }

    $actualSHA256 = [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($bytes)
    )

    if ($actualSHA256 -ne $ExpectedSHA256) {
        throw "Apple root certificate fingerprint validation failed for $Uri. Expected $ExpectedSHA256, got $actualSHA256."
    }

    return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($bytes)
}

function Get-AppleSoftwareLookup {

    Write-Output "Loading trusted Apple root certificates..."

    $appleRoots = [System.Security.Cryptography.X509Certificates.X509Certificate2[]] @(

        Get-VerifiedAppleRootCertificate `
            -Uri "https://www.apple.com/appleca/AppleIncRootCertificate.cer" `
            -ExpectedSHA256 "B0B1730ECBC7FF4505142C49F1295E6EDA6BCAED7E2C68C5BE91B5A11001F024"

        Get-VerifiedAppleRootCertificate `
            -Uri "https://www.apple.com/certificateauthority/AppleRootCA-G2.cer" `
            -ExpectedSHA256 "C2B9B042DD57830E7D117DAC55AC8AE19407D38E41D88F3215BC3A890444A050"

        Get-VerifiedAppleRootCertificate `
            -Uri "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer" `
            -ExpectedSHA256 "63343ABFB89A6A03EBB57E9B3F5FA7BE7C4F5C756F3017B3A8C488C3653E9179"
    )

    if (-not ("AppleGdmfHttpClientFactory" -as [type])) {

        $source = @"
using System;
using System.Linq;
using System.Net.Http;
using System.Net.Security;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

public static class AppleGdmfHttpClientFactory
{
    public static HttpClient Create(X509Certificate2[] trustedRoots)
    {
        var handler = new HttpClientHandler();

        handler.ServerCertificateCustomValidationCallback =
            (request, certificate, presentedChain, sslErrors) =>
            {
                if (request == null ||
                    request.RequestUri == null ||
                    !String.Equals(
                        request.RequestUri.Host,
                        "gdmf.apple.com",
                        StringComparison.OrdinalIgnoreCase))
                {
                    return false;
                }

                if (certificate == null)
                    return false;

                // Never ignore a hostname mismatch or missing certificate.
                if ((sslErrors & SslPolicyErrors.RemoteCertificateNameMismatch) != 0)
                    return false;

                if ((sslErrors & SslPolicyErrors.RemoteCertificateNotAvailable) != 0)
                    return false;

                using (var customChain = new X509Chain())
                {
                    customChain.ChainPolicy.TrustMode =
                        X509ChainTrustMode.CustomRootTrust;

                    customChain.ChainPolicy.RevocationMode =
                        X509RevocationMode.Online;

                    customChain.ChainPolicy.RevocationFlag =
                        X509RevocationFlag.ExcludeRoot;

                    customChain.ChainPolicy.VerificationFlags =
                        X509VerificationFlags.NoFlag;

                    customChain.ChainPolicy.UrlRetrievalTimeout =
                        TimeSpan.FromSeconds(10);

                    // TLS Web Server Authentication
                    customChain.ChainPolicy.ApplicationPolicy.Add(
                        new Oid("1.3.6.1.5.5.7.3.1")
                    );

                    foreach (var root in trustedRoots)
                    {
                        customChain.ChainPolicy.CustomTrustStore.Add(root);
                    }

                    // Reuse intermediates presented by the server.
                    if (presentedChain != null)
                    {
                        foreach (var element in presentedChain.ChainElements)
                        {
                            if (!String.Equals(
                                    element.Certificate.Thumbprint,
                                    certificate.Thumbprint,
                                    StringComparison.OrdinalIgnoreCase))
                            {
                                customChain.ChainPolicy.ExtraStore.Add(
                                    element.Certificate
                                );
                            }
                        }
                    }

                    return customChain.Build(certificate);
                }
            };

        var client = new HttpClient(handler, true);
        client.Timeout = TimeSpan.FromSeconds(30);

        return client;
    }
}
"@

        Add-Type -TypeDefinition $source -Language CSharp
    }

    $client = [AppleGdmfHttpClientFactory]::Create($appleRoots)

    try {

        $response = $client.GetAsync(
            $AppleLookupUri
        ).GetAwaiter().GetResult()

        if (-not $response.IsSuccessStatusCode) {
            throw "Apple Software Lookup Service returned HTTP $([int]$response.StatusCode) $($response.ReasonPhrase)."
        }

        $json = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

        if ([string]::IsNullOrWhiteSpace($json)) {
            throw "Apple Software Lookup Service returned an empty response."
        }

        return $json | ConvertFrom-Json -Depth 20
    }
    finally {

        $client.Dispose()

        foreach ($root in $appleRoots) {
            $root.Dispose()
        }
    }
}

#
# Microsoft Graph helpers
#

function Get-GraphAccessToken {

    if ([string]::IsNullOrWhiteSpace($env:IDENTITY_ENDPOINT) -or
        [string]::IsNullOrWhiteSpace($env:IDENTITY_HEADER)) {

        throw "Azure Automation Managed Identity endpoint is not available."
    }

    $headers = @{
        "X-IDENTITY-HEADER" = $env:IDENTITY_HEADER
        "Metadata"          = "True"
    }

    $body = @{
        resource = "https://graph.microsoft.com/"
    }

    $response = Invoke-RestMethod `
        -Uri $env:IDENTITY_ENDPOINT `
        -Method POST `
        -Headers $headers `
        -ContentType "application/x-www-form-urlencoded" `
        -Body $body `
        -TimeoutSec 30

    if ([string]::IsNullOrWhiteSpace($response.access_token)) {
        throw "Managed Identity did not return a Microsoft Graph access token."
    }

    return $response.access_token
}

function Invoke-GraphGet {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Uri,

        [Parameter(Mandatory = $true)]
        [string] $Token
    )

    return Invoke-RestMethod `
        -Uri $Uri `
        -Method GET `
        -Headers @{
            Authorization = "Bearer $Token"
            Accept        = "application/json"
        } `
        -TimeoutSec 30
}

#
# Retrieve Apple hardware identifiers from Intune
#

function Get-ManagedAppleDeviceModels {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Token
    )

    #
    # Graph beta is intentionally used read-only here.
    # We need deviceType, managementState and
    # hardwareInformation.productName.
    #

    $allManagedDevices = @()

    $nextUri = "$GraphBetaBaseUri/deviceManagement/managedDevices?`$select=id,deviceName,deviceType,managementState"

    while ($nextUri) {

        $response = Invoke-GraphGet `
            -Uri $nextUri `
            -Token $Token

        if ($response.value) {
            $allManagedDevices += @($response.value)
        }

        $nextUri = $response.'@odata.nextLink'
    }

    #
    # Conservative scope:
    # use all currently managed iPhones and iPads in the tenant.
    #

    $appleDevices = @(
        $allManagedDevices | Where-Object {
            $_.managementState -eq "managed" -and
            $_.deviceType -in @("iPhone", "iPad")
        }
    )

    if ($appleDevices.Count -eq 0) {
        throw "No managed iPhone or iPad devices were found in Intune."
    }

Write-Information "Managed iPhone/iPad devices found: $($appleDevices.Count)" -InformationAction Continue

    $models = @()

    foreach ($device in $appleDevices) {

        #
        # Actual hardwareInformation values must be obtained
        # using an individual device GET with $select.
        #

        $detailUri = "$GraphBetaBaseUri/deviceManagement/managedDevices/$($device.id)?`$select=id,deviceName,hardwareInformation"

        $deviceDetails = Invoke-GraphGet `
            -Uri $detailUri `
            -Token $Token

        $productName = [string]$deviceDetails.hardwareInformation.productName

        #
        # Fail closed if Intune cannot provide the hardware identifier.
        #

        if ([string]::IsNullOrWhiteSpace($productName)) {

            throw "Unable to determine hardwareInformation.productName for Intune device '$($device.deviceName)' ($($device.id)). No compliance change will be made."
        }

        #
        # Expected values:
        # iPhone17,1
        # iPhone18,2
        # iPad14,6
        #

        if ($productName -notmatch '^(iPhone|iPad)\d+,\d+$') {

            throw "Unexpected Apple productName '$productName' returned for Intune device '$($device.deviceName)'. No compliance change will be made."
        }

        $models += $productName
    }

    $uniqueModels = @(
        $models |
            Sort-Object -Unique
    )

    if ($uniqueModels.Count -eq 0) {
        throw "No valid iPhone/iPad hardware models could be determined from Intune."
    }

    return $uniqueModels
}

#
# Start
#

Write-Output "=== Intune iOS minimum version automation ==="
Write-Output "Policy: $PolicyDisplayName"
Write-Output "DryRun: $DryRun"

#
# 1. Get current public Apple releases
#

Write-Output "Querying Apple Software Lookup Service..."

$appleResponse = Get-AppleSoftwareLookup

if (-not $appleResponse.PublicAssetSets -or
    -not $appleResponse.PublicAssetSets.iOS) {

    throw "Apple response does not contain the expected PublicAssetSets.iOS structure."
}

#
# Keep valid, non-expired public releases applicable
# to at least one iPhone or iPad.
#

$mobileAssets = @(
    $appleResponse.PublicAssetSets.iOS | Where-Object {

        $validVersion =
            $_.ProductVersion -match '^\d+(\.\d+){1,2}$'

        $hasMobileDevice = @(
            $_.SupportedDevices | Where-Object {
                $_ -match '^(iPhone|iPad)'
            }
        ).Count -gt 0

        $notExpired = $true

        if ($_.ExpirationDate) {

            try {

                $expiration =
                    [datetime]$_.ExpirationDate

                $notExpired =
                    $expiration.ToUniversalTime() -gt
                    (Get-Date).ToUniversalTime()
            }
            catch {

                #
                # Invalid expiration date = reject release.
                #

                $notExpired = $false
            }
        }

        $validVersion -and
        $hasMobileDevice -and
        $notExpired
    }
)

if ($mobileAssets.Count -eq 0) {
    throw "No valid iPhone/iPad releases were returned by Apple."
}

#
# Convert Apple releases into predictable objects.
#

$versionCandidates = @()

foreach ($asset in $mobileAssets) {

    try {

        $versionObject =
            [version]$asset.ProductVersion

        $postingDate = $null

        if ($asset.PostingDate) {
            $postingDate =
                [datetime]$asset.PostingDate
        }

        $versionCandidates += [PSCustomObject]@{
            ProductVersion   = $asset.ProductVersion
            Version          = $versionObject
            PostingDate      = $postingDate
            SupportedDevices = @($asset.SupportedDevices)
        }
    }
    catch {

        Write-Warning "Ignoring invalid Apple version '$($asset.ProductVersion)'."
    }
}

if ($versionCandidates.Count -eq 0) {
    throw "Apple returned no ProductVersion values that can be parsed."
}

#
# 2. Get Graph token and Intune hardware inventory
#

Write-Output "Obtaining Microsoft Graph token using Managed Identity..."

$token = Get-GraphAccessToken

Write-Output "Reading managed iPhone/iPad hardware inventory from Intune..."

$managedModels = @(
    Get-ManagedAppleDeviceModels `
        -Token $token
)

Write-Output "Managed Apple models: $($managedModels -join ', ')"

#
# Determine the latest public release available
# for EACH managed hardware model.
#
# This is critical because Apple can release an update
# for only selected models.
#

$modelLatestReleases = @()

foreach ($model in $managedModels) {

    $latestForModel =
        $versionCandidates |
        Where-Object {
            $_.SupportedDevices -contains $model
        } |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $latestForModel) {

        throw "Apple Software Lookup Service contains no current release for managed model '$model'. No compliance change will be made."
    }

    #
    # Future PostingDate is suspicious.
    #

    if ($latestForModel.PostingDate -and
        $latestForModel.PostingDate -gt
        (Get-Date).ToUniversalTime().AddDays(1)) {

        throw "Apple returned a PostingDate in the future for model '$model': $($latestForModel.PostingDate)"
    }

    Write-Output "Latest available Apple release for ${model}: $($latestForModel.ProductVersion)"

    $modelLatestReleases += [PSCustomObject]@{
        Model          = $model
        ProductVersion = $latestForModel.ProductVersion
        Version        = $latestForModel.Version
        PostingDate    = $latestForModel.PostingDate
    }
}

if ($modelLatestReleases.Count -eq 0) {

    throw "Unable to determine latest Apple releases for managed hardware."
}

#
# The compliance minimum must be achievable
# by EVERY managed model.
#
# Example:
#
# iPhone A -> 27.0.1
# iPhone B -> 27.0
#
# Safe tenant-wide minimum = 27.0
#

$lowestLatestRelease =
    $modelLatestReleases |
    Sort-Object Version |
    Select-Object -First 1

$targetVersionText =
    $lowestLatestRelease.ProductVersion

$targetVersion =
    $lowestLatestRelease.Version

#
# PostingDate is used only for logging/sanity validation.
#

$targetPostingDate = (
    $modelLatestReleases |
        Where-Object {
            $_.Version -eq $targetVersion -and
            $_.PostingDate
        } |
        Sort-Object PostingDate -Descending |
        Select-Object -First 1
).PostingDate

Write-Output "Safe fleet-wide iOS/iPadOS minimum version: $targetVersionText"

if ($targetPostingDate) {
    Write-Output "Target version posting date: $targetPostingDate"
}

#
# 3. Find the Intune compliance policy
#

Write-Output "Looking for Intune compliance policy '$PolicyDisplayName'..."

$allPolicies = @()

$nextUri =
    "$GraphBaseUri/deviceManagement/deviceCompliancePolicies"

while ($nextUri) {

    $response =
        Invoke-GraphGet `
            -Uri $nextUri `
            -Token $token

    if ($response.value) {
        $allPolicies +=
            @($response.value)
    }

    $nextUri =
        $response.'@odata.nextLink'
}

#
# Exact display name + exact iOS policy type.
#

$matchingPolicies = @(
    $allPolicies | Where-Object {

        $_.displayName -eq $PolicyDisplayName -and
        $_.'@odata.type' -eq "#microsoft.graph.iosCompliancePolicy"
    }
)

if ($matchingPolicies.Count -eq 0) {

    throw "No iOS compliance policy named '$PolicyDisplayName' was found."
}

if ($matchingPolicies.Count -gt 1) {

    throw "More than one iOS compliance policy named '$PolicyDisplayName' was found."
}

$policy =
    $matchingPolicies[0]

if ([string]::IsNullOrWhiteSpace(
        $policy.osMinimumVersion
    )) {

    throw "The current compliance policy does not have osMinimumVersion configured."
}

try {

    $currentVersion =
        [version]$policy.osMinimumVersion
}
catch {

    throw "Current Intune osMinimumVersion '$($policy.osMinimumVersion)' cannot be parsed."
}

Write-Output "Current Intune minimum version: $($policy.osMinimumVersion)"

#
# Respect an existing maximum OS version if configured.
#

if (-not [string]::IsNullOrWhiteSpace(
        $policy.osMaximumVersion
    )) {

    try {

        $maximumVersion =
            [version]$policy.osMaximumVersion
    }
    catch {

        throw "Current Intune osMaximumVersion '$($policy.osMaximumVersion)' cannot be parsed."
    }

    if ($targetVersion -gt
        $maximumVersion) {

        throw "Apple target version $targetVersionText exceeds configured Intune maximum OS version $($policy.osMaximumVersion). No change will be made."
    }
}

#
# 4. Fail-safe checks
#

#
# Never automatically downgrade.
#

if ($targetVersion -lt $currentVersion) {

    throw "Apple target version $targetVersionText is LOWER than current Intune version $($policy.osMinimumVersion). Automatic downgrade is prohibited."
}

#
# Nothing to do.
#

if ($targetVersion -eq $currentVersion) {

    Write-Output "No change required. Intune already requires iOS $($policy.osMinimumVersion)."

    return
}

#
# Limit automatic major-version jumps.
#
# MaxMajorJump = 1 allows:
#
# 26.x -> 27.x
#
# but rejects:
#
# 26.x -> 28.x
#

if ($targetVersion.Major -gt
    ($currentVersion.Major + $MaxMajorJump)) {

    throw "Major version jump is too large: $($policy.osMinimumVersion) -> $targetVersionText. Maximum automatic jump is $MaxMajorJump major version."
}

Write-Output "Newer iOS version detected: $($policy.osMinimumVersion) -> $targetVersionText"

#
# 5. Dry run
#

if ($DryRun) {

    Write-Output "DRY RUN: Compliance policy would be changed to iOS $targetVersionText."

    return
}

#
# 6. Re-read policy immediately before PATCH
#

$patchUri =
    "$GraphBaseUri/deviceManagement/deviceCompliancePolicies/$($policy.id)"

#
# Prevent overwriting a manual administrative change
# made while this Automation job was running.
#

$policyBeforePatch =
    Invoke-GraphGet `
        -Uri $patchUri `
        -Token $token

if ([string]::IsNullOrWhiteSpace(
        $policyBeforePatch.osMinimumVersion
    )) {

    throw "Pre-update validation failed: osMinimumVersion is empty."
}

try {

    $versionBeforePatch =
        [version]$policyBeforePatch.osMinimumVersion
}
catch {

    throw "Pre-update validation failed: osMinimumVersion '$($policyBeforePatch.osMinimumVersion)' cannot be parsed."
}

#
# Another administrator/job may already have made
# exactly the change we wanted.
#

if ($versionBeforePatch -eq
    $targetVersion) {

    Write-Output "No change required. Policy was already changed to iOS $targetVersionText while this job was running."

    return
}

#
# Any other change = abort.
#

if ($versionBeforePatch -ne
    $currentVersion) {

    throw "Compliance policy changed while this job was running: originally $currentVersion, now $versionBeforePatch. No automatic update will be performed."
}

#
# Re-check maximum OS version immediately before PATCH.
#

if (-not [string]::IsNullOrWhiteSpace(
        $policyBeforePatch.osMaximumVersion
    )) {

    try {

        $maximumVersionBeforePatch =
            [version]$policyBeforePatch.osMaximumVersion
    }
    catch {

        throw "Pre-update validation failed: osMaximumVersion '$($policyBeforePatch.osMaximumVersion)' cannot be parsed."
    }

    if ($targetVersion -gt
        $maximumVersionBeforePatch) {

        throw "Apple target version $targetVersionText exceeds the current Intune maximum OS version $($policyBeforePatch.osMaximumVersion). No change will be made."
    }
}

#
# 7. Update Intune
#

$patchBody = @{
    "@odata.type"    = "#microsoft.graph.iosCompliancePolicy"
    osMinimumVersion = $targetVersionText
} | ConvertTo-Json

Write-Output "Updating Intune compliance policy..."

Invoke-RestMethod `
    -Uri $patchUri `
    -Method PATCH `
    -Headers @{
        Authorization = "Bearer $token"
        Accept        = "application/json"
    } `
    -ContentType "application/json" `
    -Body $patchBody `
    -TimeoutSec 30 |
    Out-Null

#
# 8. Verify the change
#

Write-Output "Verifying the change..."

$verifiedPolicy =
    Invoke-GraphGet `
        -Uri $patchUri `
        -Token $token

if ([string]::IsNullOrWhiteSpace(
        $verifiedPolicy.osMinimumVersion
    )) {

    throw "Verification failed: osMinimumVersion is empty after PATCH."
}

try {

    $verifiedVersion =
        [version]$verifiedPolicy.osMinimumVersion
}
catch {

    throw "Verification failed: Intune returned an invalid osMinimumVersion '$($verifiedPolicy.osMinimumVersion)'."
}

if ($verifiedVersion -ne
    $targetVersion) {

    throw "Verification failed. Expected $targetVersionText but Intune reports $($verifiedPolicy.osMinimumVersion)."
}

Write-Output "SUCCESS: '$PolicyDisplayName' changed from $($policy.osMinimumVersion) to $($verifiedPolicy.osMinimumVersion)."
