#Requires -Version 5.1
<#
  MyMeetings API runtime smoke test (read-only; optional mutating). Mirrors
  scripts/api/runtime-api-smoke-test.sh — set the same MYMEETINGS_* environment variables.

  Uses Invoke-RestMethod/Invoke-WebRequest (no external curl or Python on Windows;
  the bash script uses python3 and curl for identical logic).
#>
param(
  [string] $Base = $(if ($env:MYMEETINGS_BASE_URL) { $env:MYMEETINGS_BASE_URL } else { "http://localhost:5000" })
)

$Base = $Base.TrimEnd("/")
$MUser = if ($env:MYMEETINGS_MEMBER_USERNAME) { $env:MYMEETINGS_MEMBER_USERNAME } else { "testMember@mail.com" }
$MPass = if ($env:MYMEETINGS_MEMBER_PASSWORD) { $env:MYMEETINGS_MEMBER_PASSWORD } else { "testMemberPass" }
$AUser = if ($env:MYMEETINGS_ADMIN_USERNAME)  { $env:MYMEETINGS_ADMIN_USERNAME }  else { "testAdmin@mail.com" }
$APass = if ($env:MYMEETINGS_ADMIN_PASSWORD)  { $env:MYMEETINGS_ADMIN_PASSWORD }  else { "testAdminPass" }
$doMut  = ($env:MYMEETINGS_INCLUDE_MUTATING -eq "1")
$OKE = 0; $FAILN = 0
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Pass  { param([string] $M) $script:OKE++;  Write-Output ("[ OK ] {0}" -f $M) }
function LogFail { param([string] $M) $script:FAILN++; Write-Warning ("[FAIL] {0}" -f $M) }
function Info  { param([string] $M) Write-Output ("       {0}" -f $M) }
function HttpStatus {
  param(
    [ValidateSet("GET","POST","PUT","PATCH","DELETE")]
    [string] $Method,
    [string] $Path,
    [string] $Token = $null,
    [string] $JsonBody = $null
  )
  $U = if ($Path -cmatch "^\s*https?://") { $Path } else { $Base + $Path }
  $H = @{}
  if ($Token) { $H["Authorization"] = "Bearer " + $Token }
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Stop"
  try {
    if ($JsonBody) {
      $resp = Invoke-WebRequest -Method $Method -Uri $U -Headers $H -Body $JsonBody -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    } else {
      $resp = Invoke-WebRequest -Method $Method -Uri $U -Headers $H -UseBasicParsing -ErrorAction Stop
    }
    return [int]$resp.StatusCode
  } catch {
    if ($null -ne $_.Exception -and $null -ne $_.Exception.Response) {
      [int]$_.Exception.Response.StatusCode
    } else { 0 }
  } finally {
    $ErrorActionPreference = $prev
  }
}

function Expect { param($Code, $Expected, $Label) if ($Code -eq $Expected) { Pass ("{0} (HTTP {1})" -f $Label, $Code) } else { LogFail ("{0} — expected {1}, got {2}" -f $Label, $Expected, $Code) } }
function New-AccessToken { param($U, $P)
  $b = "grant_type=password&username=" + [uri]::EscapeDataString($U) + "&password=" + [uri]::EscapeDataString($P) + "&client_id=ro.client&client_secret=secret"
  try { (Invoke-RestMethod -Method Post -Uri ($Base + "/connect/token") -ContentType "application/x-www-form-urlencoded" -Body $b -ErrorAction Stop).access_token }
  catch { $null }
}

$firstMeetingId = $null
$firstGroupId   = $null
Write-Output "Base URL: $Base`n"
$c = HttpStatus "GET" "/swagger/v1/swagger.json" -Token $null
Expect -Code $c -Expected 200 -Label "GET /swagger/v1/swagger.json (OpenAPI)"
$memberT = New-AccessToken -U $MUser -P $MPass
$adminT  = New-AccessToken -U $AUser  -P $APass
if ([string]::IsNullOrEmpty($memberT) -or [string]::IsNullOrEmpty($adminT)) { Write-Error "Token request failed (is the API and IdentityServer running at the base URL?)" ; exit 1 }

$paths = @(
  "/api/userAccess/authenticatedUser",
  "/api/userAccess/authenticatedUser/permissions",
  "/api/userAccess/emails",
  "/api/meetings/meetings",
  "/api/meetings/countries",
  "/api/meetings/MeetingGroups",
  "/api/meetings/MeetingGroups/all",
  "/api/meetings/MeetingGroupProposals",
  "/api/meetings/MeetingGroupProposals/all",
  "/api/payments/priceListItems",
  "/api/payments/payers/authenticated/subscription"
)
foreach ($p in $paths) { $c = (HttpStatus "GET" $p -Token $memberT); Expect -Code $c -Expected 200 -Label ("GET " + $p) }

# Optional meeting and group by id
try { $mList = Invoke-RestMethod -Method Get -Uri ($Base + "/api/meetings/meetings") -Headers @{ "Authorization" = "Bearer " + $memberT } } catch { $mList = @() }
$ma = @($mList)
if ($ma.Count -gt 0) {
  $o = $ma[0]
  $firstMeetingId = if ($o.PSObject.Properties['meetingId']) { $o.meetingId } elseif ($o.PSObject.Properties['MeetingId']) { $o.MeetingId } else { $null }
  if ($firstMeetingId) {
    $c = (HttpStatus "GET" ("/api/meetings/meetings/" + $firstMeetingId) -Token $memberT)
    Expect -Code $c -Expected 200 -Label "GET /api/meetings/meetings/{meetingId}"
    $c2 = (HttpStatus "GET" ("/api/meetings/meetings/" + $firstMeetingId + "/attendees") -Token $memberT)
    Expect -Code $c2 -Expected 200 -Label "GET /api/meetings/meetings/{meetingId}/attendees"
  }
} else { Info "SKIP meeting-by-id and attendees — no meetings in database" }

try { $gList = Invoke-RestMethod -Method Get -Uri ($Base + "/api/meetings/MeetingGroups") -Headers @{ "Authorization" = "Bearer " + $memberT } } catch { $gList = @() }
$ga = @($gList)
if ($ga.Count -gt 0) {
  $g = $ga[0]
  $firstGroupId = if ($g.PSObject.Properties['id']) { $g.id } elseif ($g.PSObject.Properties['Id']) { $g.Id } else { $null }
  if ($firstGroupId) { $c = (HttpStatus "GET" ("/api/meetings/MeetingGroups/" + $firstGroupId) -Token $memberT); Expect -Code $c -Expected 200 -Label "GET /api/meetings/MeetingGroups/{meetingGroupId}" }
} else { Info "SKIP group-by-id — no groups in list" }
$c3 = (HttpStatus "GET" "/api/administration/meetingGroupProposals" -Token $adminT); Expect -Code $c3 -Expected 200 -Label "GET /api/administration/meetingGroupProposals (admin)"

if ($doMut) {
  Write-Output ("`n--- MYMEETINGS_INCLUDE_MUTATING=1 (data changes) ---")
  $r = "smoke" + (Get-Date -UFormat %s) + (Get-Random) + "x"
  $j = ( @{
      Login = "t$r" ; Password = "P@ss$($r)9" ; Email = "t$r@ex.com" ; FirstName = "A" ; LastName = "B" ; ConfirmLink = "http://l/c"
    } | ConvertTo-Json -Compress)
  $c4 = (HttpStatus "POST" "/userAccess/UserRegistrations" -Token $null -JsonBody $j)
  Expect -Code $c4 -Expected 200 -Label "POST /userAccess/UserRegistrations"
  $c5 = (HttpStatus "POST" "/api/payments/subscriptionPayments" -Token $memberT -JsonBody '{"paymentId":"00000000-0000-0000-0000-000000000000"}')
  Info ("POST /api/payments/subscriptionPayments (dummy id) → {0} (expected 4xx/5xx often)" -f $c5)
  $c6 = (HttpStatus "POST" "/api/payments/subscriptionRenewals" -Token $memberT -JsonBody '{"paymentId":"00000000-0000-0000-0000-000000000000"}')
  Info ("POST /api/payments/subscriptionRenewals (dummy) → {0}" -f $c6)
  $c7 = (HttpStatus "POST" "/api/payments/meetingFeePayments" -Token $memberT -JsonBody '{"meetingFeeId":"00000000-0000-0000-0000-000000000000"}')
  Info ("POST /api/payments/meetingFeePayments (dummy) → {0}" -f $c7)
} else { Info "Mutating requests skipped. Set MYMEETINGS_INCLUDE_MUTATING=1" }

Write-Output ("`nDone. Passed: {0}  Failed: {1}" -f $OKE, $FAILN)
if ($FAILN -gt 0) { exit 1 }
