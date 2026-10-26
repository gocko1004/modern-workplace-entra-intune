[Version française](fr/ARCHITECTURE.md)

# Architecture

The tenant from the top down: me as Global Administrator, the tenant, then its seven parts. The
[interactive diagram](https://gocko1004.github.io/modern-workplace-entra-intune/?lang=en) opens one level per
click, down to each policy, and says why each part is built the way it is.

[![The tenant from the top: me as Global Administrator, the tenant, its seven parts and what sits under each](architecture/tenant-overview-en.png)](https://gocko1004.github.io/modern-workplace-entra-intune/?lang=en)

Below, the tour I present in eight steps, with the screenshots numbered in its order. Every element and every
connection is also on [one full map](architecture/tenant-architecture-en.png), under the names used on this
page. *Test user* on the map is `lea.test` in the rest of this repo.

## The tour, step by step

| Step | In the diagram | Screenshots | Pages |
|---|---|---|---|
| 1 · The tenant | Business Premium<br>Intune Plan 1<br>Intune Suite<br>Entra ID P2 | Live: Microsoft 365 admin center › Billing › Licenses | [What the lab covers](README.md#what-the-lab-covers) |
| 2 · Identities | Daily admin<br>emergency-access-01<br>Test user<br>EmergencyAccess<br>Dyn-Autopilot-Devices<br>Global Administrator | Live: Entra › Users, Groups, Roles and administrators | [Identity](identity/README.md) |
| 3 · Never lose access | emergency-access-01<br>EmergencyAccess<br>Passkey (FIDO2)<br>Temporary Access Pass<br>Daily admin<br>Microsoft Authenticator | [01](screenshots/01-emergency-access-tap-sign-in.png) [02](screenshots/02-emergency-access-passkey-only.png) [03](screenshots/03-emergency-access-passkey-aaguid.png) | [Emergency account](identity/README.md#1-an-emergency-access-account-before-any-policy), [Passkey](identity/README.md#2-a-passkey-on-an-account-with-no-methods) |
| 4 · Access rules | CA001 · MFA for all users<br>CA002 · Block legacy authentication<br>CA003 · Compliant device (Windows)<br>Security defaults<br>EmergencyAccess | [04](screenshots/04-access-rules-no-policies-after-teardown.png) [05](screenshots/05-access-rules-security-defaults-off.png) [06](screenshots/06-access-rules-lockout-warning.png) [07](screenshots/07-access-rules-whatif-test-user.png) [08](screenshots/08-access-rules-whatif-emergencyaccess-excluded.png) [09](screenshots/09-access-rules-report-only-sign-in.png) [10](screenshots/10-access-rules-ca001-ca002-ca003-on.png) | [Conditional Access](identity/README.md#4-conditional-access) |
| 5 · The workstation | CORP-97322<br>Autopilot · APUserDrivenEntraJoin<br>Automatic enrolment (MDM)<br>Dyn-Autopilot-Devices<br>CP-Windows<br>ES-BitLocker-OS<br>ES-Defender-AV<br>CFG-Edge-SmartScreen<br>Device settings | [11](screenshots/11-workstation-mdm-authority-none.png) [12](screenshots/12-workstation-dyn-autopilot-devices.png) [13](screenshots/13-workstation-autopilot-apuserdrivenentrajoin.png) [14](screenshots/14-workstation-corp-97322-encrypted.png) [15](screenshots/15-workstation-cp-windows-compliant.png) [16](screenshots/16-workstation-cfg-edge-smartscreen.png) | [The Autopilot chain](rebuild/README.md#the-autopilot-chain), [Compliance](rebuild/README.md#compliance) |
| 6 · Check, don't assume | Sign-in logs<br>Audit logs<br>identity-audit.ps1<br>Microsoft Graph | [17](screenshots/17-checks-audit-exclusion-was-the-user.png) [18](screenshots/18-checks-audit-exclusion-fixed.png) [19](screenshots/19-checks-audit-emergency-sign-ins.png) [20](screenshots/20-checks-audit-test-user-sign-ins.png) [21](screenshots/21-checks-bitlocker-portal-access-denied.png) [22](screenshots/22-checks-bitlocker-graph-403.png) [23](screenshots/23-checks-bitlocker-graph-200-ok.png) [24](screenshots/24-checks-bitlocker-three-recovery-keys.png) [25](screenshots/25-checks-defender-pua-protection-off.png) | [Checking it with PowerShell](identity/README.md#5-checking-it-with-powershell), [Lab log](LAB-LOG.md) |
| 7 · Tear down and rebuild | 20 users, including anna.test<br>Android phone<br>Windows LAPS<br>ASR, App Control, EPM<br>Assignment filters<br>Microsoft 365 Apps<br>Microsoft365DSC export<br>Rebuild scripts<br>GitHub repo | [26](screenshots/26-first-round-update-pin-24h2-deploys-25h2.png) [27](screenshots/27-first-round-firewall-merge-conflict.png) [28](screenshots/28-first-round-ca-whatif-report-only.png) [29](screenshots/29-first-round-7zip-installed.png) [30](screenshots/30-first-round-app-protection-on-devices.png) | [Teardown of 14 September](teardown/README.md), [Rebuild](rebuild/README.md) |
| 8 · What I would do next | Every open point, with the Open points button | Live: the open points | [Still to do](identity/README.md#still-to-do) |

The October 2025 pipeline sits outside the diagram: [31](screenshots/31-pipeline-2025-secret-login.png) [32](screenshots/32-pipeline-2025-secret-readable.png), told in
[identity/workload-identity-2025.md](identity/workload-identity-2025.md).

## Every element with a screenshot

| Zone | Name in the diagram | Screenshots |
|---|---|---|
| (01) Identities | emergency-access-01 | [01](screenshots/01-emergency-access-tap-sign-in.png) [02](screenshots/02-emergency-access-passkey-only.png) [03](screenshots/03-emergency-access-passkey-aaguid.png) [08](screenshots/08-access-rules-whatif-emergencyaccess-excluded.png) [19](screenshots/19-checks-audit-emergency-sign-ins.png) |
| (01) Identities | Test user | [07](screenshots/07-access-rules-whatif-test-user.png) [09](screenshots/09-access-rules-report-only-sign-in.png) [20](screenshots/20-checks-audit-test-user-sign-ins.png) |
| (01) Identities | EmergencyAccess | [08](screenshots/08-access-rules-whatif-emergencyaccess-excluded.png) [17](screenshots/17-checks-audit-exclusion-was-the-user.png) [18](screenshots/18-checks-audit-exclusion-fixed.png) |
| (01) Identities | Dyn-Autopilot-Devices | [12](screenshots/12-workstation-dyn-autopilot-devices.png) |
| (02) Access | Passkey (FIDO2) | [02](screenshots/02-emergency-access-passkey-only.png) [03](screenshots/03-emergency-access-passkey-aaguid.png) |
| (02) Access | Temporary Access Pass | [01](screenshots/01-emergency-access-tap-sign-in.png) |
| (02) Access | Windows Hello for Business | [20](screenshots/20-checks-audit-test-user-sign-ins.png) |
| (02) Access | CA001 · MFA for all users<br>`CA001-Require-MFA-All-Users` | [04](screenshots/04-access-rules-no-policies-after-teardown.png) [06](screenshots/06-access-rules-lockout-warning.png) [07](screenshots/07-access-rules-whatif-test-user.png) [09](screenshots/09-access-rules-report-only-sign-in.png) [10](screenshots/10-access-rules-ca001-ca002-ca003-on.png) [17](screenshots/17-checks-audit-exclusion-was-the-user.png) [18](screenshots/18-checks-audit-exclusion-fixed.png) |
| (02) Access | CA002 · Block legacy authentication<br>`CA002-Block-Legacy-Authentication` | [04](screenshots/04-access-rules-no-policies-after-teardown.png) [09](screenshots/09-access-rules-report-only-sign-in.png) [10](screenshots/10-access-rules-ca001-ca002-ca003-on.png) [17](screenshots/17-checks-audit-exclusion-was-the-user.png) [18](screenshots/18-checks-audit-exclusion-fixed.png) |
| (02) Access | CA003 · Compliant device (Windows)<br>`CA003-Require-Compliant-Device-Windows` | [04](screenshots/04-access-rules-no-policies-after-teardown.png) [07](screenshots/07-access-rules-whatif-test-user.png) [09](screenshots/09-access-rules-report-only-sign-in.png) [10](screenshots/10-access-rules-ca001-ca002-ca003-on.png) [17](screenshots/17-checks-audit-exclusion-was-the-user.png) [18](screenshots/18-checks-audit-exclusion-fixed.png) [28](screenshots/28-first-round-ca-whatif-report-only.png) |
| (02) Access | Security defaults | [05](screenshots/05-access-rules-security-defaults-off.png) |
| (03) Devices | CORP-97322 | [14](screenshots/14-workstation-corp-97322-encrypted.png) [15](screenshots/15-workstation-cp-windows-compliant.png) [16](screenshots/16-workstation-cfg-edge-smartscreen.png) |
| (03) Devices | Autopilot · APUserDrivenEntraJoin | [13](screenshots/13-workstation-autopilot-apuserdrivenentrajoin.png) |
| (03) Devices | Automatic enrolment (MDM) | [11](screenshots/11-workstation-mdm-authority-none.png) |
| (03) Devices | CP-Windows | [15](screenshots/15-workstation-cp-windows-compliant.png) |
| (03) Devices | ES-BitLocker-OS | [14](screenshots/14-workstation-corp-97322-encrypted.png) [21](screenshots/21-checks-bitlocker-portal-access-denied.png) [22](screenshots/22-checks-bitlocker-graph-403.png) [23](screenshots/23-checks-bitlocker-graph-200-ok.png) [24](screenshots/24-checks-bitlocker-three-recovery-keys.png) |
| (03) Devices | ES-Defender-AV | [25](screenshots/25-checks-defender-pua-protection-off.png) |
| (03) Devices | CFG-Edge-SmartScreen | [16](screenshots/16-workstation-cfg-edge-smartscreen.png) |
| (04) Services | Microsoft Graph | [22](screenshots/22-checks-bitlocker-graph-403.png) [23](screenshots/23-checks-bitlocker-graph-200-ok.png) |
| (06) Checks and tools | Sign-in logs | [09](screenshots/09-access-rules-report-only-sign-in.png) [19](screenshots/19-checks-audit-emergency-sign-ins.png) [20](screenshots/20-checks-audit-test-user-sign-ins.png) |
| (06) Checks and tools | identity-audit.ps1 | [17](screenshots/17-checks-audit-exclusion-was-the-user.png) [18](screenshots/18-checks-audit-exclusion-fixed.png) [19](screenshots/19-checks-audit-emergency-sign-ins.png) [20](screenshots/20-checks-audit-test-user-sign-ins.png) |
| (07) Built in phase 1, then torn down | Microsoft 365 Apps | [29](screenshots/29-first-round-7zip-installed.png) [30](screenshots/30-first-round-app-protection-on-devices.png) |

All 32 screenshots are described in [screenshots/README.md](screenshots/README.md), under the same step titles.
