# identity-audit.ps1
# Read-only. Four checks on the identity setup, through Microsoft Graph. Changes nothing.
#
#   1. Conditional Access policies: state, who is excluded, what they require
#   2. The emergency account: its sign-in methods, groups and roles
#   3. Recent sign-ins of the emergency account and the test user, with the method used
#   4. App registrations that hold client secrets, and when each one expires
#
# Needs only the Microsoft.Graph.Authentication module (Invoke-MgGraphRequest).
# Run here as a Global Administrator. Global Reader should cover these read scopes (not tested).
# The first run asks to consent to the read scopes below.
#
#   .\identity-audit.ps1 -EmergencyUpn <emergency account UPN> -TestUserUpn <test user UPN>
#   Add -LogPath <file> to keep a copy of everything printed, errors included.

param(
    [Parameter(Mandatory)] [string] $EmergencyUpn,
    [Parameter(Mandatory)] [string] $TestUserUpn,
    [string] $LogPath
)

$ErrorActionPreference = 'Stop'
if ($LogPath) { Start-Transcript -Path $LogPath -Force | Out-Null }

Connect-MgGraph -NoWelcome -Scopes 'Policy.Read.All', 'Directory.Read.All', 'AuditLog.Read.All',
    'UserAuthenticationMethod.Read.All', 'Application.Read.All'

# Graph returns results in pages. Follow @odata.nextLink until there are none left.
function Get-GraphAll([string] $Uri) {
    $items = @()
    while ($Uri) {
        $page  = Invoke-MgGraphRequest -Method GET -Uri $Uri
        $items += $page.value
        $Uri   = $page.'@odata.nextLink'
    }
    $items
}

# A check that fails prints why, and the next check still runs. Silence is not a result.
function Invoke-Check([string] $Title, [scriptblock] $Body) {
    try { & $Body }
    catch {
        Write-Host "`n=== $Title : FAILED ===" -ForegroundColor Red
        Write-Host "  $($_.Exception.GetType().Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show([string] $Title, $Rows) {
    Write-Host "`n=== $Title ===" -ForegroundColor Cyan
    if (-not $Rows) { Write-Host '  (none)' -ForegroundColor Yellow; return }
    $Rows | Format-Table -AutoSize -Wrap | Out-String -Width 200 | Write-Host
}

# ---------------------------------------------------------------------------
# 1. Conditional Access policies
#    state: enabled = On, enabledForReportingButNotEnforced = Report-only, disabled = Off
# ---------------------------------------------------------------------------

$groupName = @{}
function Get-GroupName([string] $Id) {
    if (-not $groupName[$Id]) {
        $groupName[$Id] = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$Id`?`$select=displayName").displayName
    }
    $groupName[$Id]
}

# Users can be listed by ID; show their display name instead. 'All' and 'None' stay as they are.
$userName = @{}
function Get-UserName([string] $Id) {
    if ($Id -notmatch '^[0-9a-f-]{36}$') { return $Id }
    if (-not $userName[$Id]) {
        $userName[$Id] = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$Id`?`$select=displayName").displayName
    }
    $userName[$Id]
}

Invoke-Check 'Conditional Access policies' {
    $policies = Get-GraphAll 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies'
    Show 'Conditional Access policies' ($policies | Sort-Object displayName | ForEach-Object {
        [pscustomobject]@{
            Policy         = $_.displayName
            State          = $_.state
            IncludeUsers   = (($_.conditions.users.includeUsers | ForEach-Object { Get-UserName $_ }) -join ', ')
            ExcludedUsers  = (($_.conditions.users.excludeUsers | ForEach-Object { Get-UserName $_ }) -join ', ')
            ExcludedGroups = (($_.conditions.users.excludeGroups | ForEach-Object { Get-GroupName $_ }) -join ', ')
            Requires       = (@($_.grantControls.builtInControls) -join ', ')
        }
    })
}

# ---------------------------------------------------------------------------
# 2. The emergency account
#    Expected: a password and one passkey, nothing else; member of EmergencyAccess;
#    Global Administrator.
# ---------------------------------------------------------------------------

Invoke-Check 'Emergency account: sign-in methods' {
    $methods = Get-GraphAll "https://graph.microsoft.com/v1.0/users/$EmergencyUpn/authentication/methods"
    Show 'Emergency account: sign-in methods' ($methods | ForEach-Object {
        [pscustomobject]@{
            Method      = ($_.'@odata.type' -replace '#microsoft.graph.', '' -replace 'AuthenticationMethod', '')
            Name        = $_.displayName
            AAGUID      = $_.aaGuid
            Attestation = $_.attestationLevel
        }
    })
}

Invoke-Check 'Emergency account: groups and roles' {
    $memberOf = Get-GraphAll "https://graph.microsoft.com/v1.0/users/$EmergencyUpn/memberOf"
    Show 'Emergency account: groups and roles' ($memberOf | ForEach-Object {
        [pscustomobject]@{
            Type = ($_.'@odata.type' -replace '#microsoft.graph.', '')
            Name = $_.displayName
        }
    })
}

# ---------------------------------------------------------------------------
# 3. Recent interactive sign-ins, with the method used
#    authenticationDetails exists only on the beta endpoint, not on v1.0.
# ---------------------------------------------------------------------------

foreach ($upn in $EmergencyUpn, $TestUserUpn) { Invoke-Check "Sign-ins: $upn" {
    $uri = "https://graph.microsoft.com/beta/auditLogs/signIns?`$filter=userPrincipalName eq '$upn'&`$top=10"
    $signIns = (Invoke-MgGraphRequest -Method GET -Uri $uri).value
    Show "Sign-ins: $($upn.Split('@')[0])" ($signIns | ForEach-Object {
        [pscustomobject]@{
            TimeUtc  = $_.createdDateTime
            App      = $_.appDisplayName
            Result   = if ($_.status.errorCode -eq 0) { 'Success' } else { "Error $($_.status.errorCode)" }
            CA       = $_.conditionalAccessStatus
            Methods  = (($_.authenticationDetails | ForEach-Object { "$($_.authenticationMethod) [$($_.succeeded)]" }) -join '; ')
        }
    })
} }

# ---------------------------------------------------------------------------
# 4. App registrations with client secrets
#    A client secret is a password for an application. Each one should have an owner
#    and an expiry someone is watching.
# ---------------------------------------------------------------------------

Invoke-Check 'App registrations holding client secrets' {
    $apps = Get-GraphAll 'https://graph.microsoft.com/v1.0/applications?$select=displayName,passwordCredentials'
    Show 'App registrations holding client secrets' ($apps | Where-Object { $_.passwordCredentials } | ForEach-Object {
        $app = $_
        $app.passwordCredentials | ForEach-Object {
            [pscustomobject]@{
                App      = $app.displayName
                Secret   = $_.displayName
                Expires  = $_.endDateTime
                DaysLeft = [int]((Get-Date $_.endDateTime) - (Get-Date)).TotalDays
            }
        }
    })
}

Write-Host "`n=== Done ===`n" -ForegroundColor Cyan
if ($LogPath) { Stop-Transcript | Out-Null }
