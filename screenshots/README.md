# Screenshots

Taken in my tenant and redacted before upload. Tenant name, tenant and device IDs, admin accounts,
serial numbers, recovery keys and passwords are blacked out, not blurred.

Numbered in the order of the guided tour in [ARCHITECTURE.md](../ARCHITECTURE.md). Each heading below
is a step of the tour, with its title in the diagram in brackets. Steps 1, 2 and 8 are shown live in
the portals, not in screenshots.

## Step 3 · Never lose access (Ne jamais perdre l'accès)

| Screenshot | What it shows | Why it matters | Page |
|---|---|---|---|
| `01-emergency-access-tap-sign-in.png` | A sign-in authenticated with a **Temporary Access Pass** | How an account with no methods gets its first strong one, to register a passkey | [Identity](../identity/README.md#2-a-passkey-on-an-account-with-no-methods) |
| `02-emergency-access-passkey-only.png` | Emergency account with one usable method, a **passkey**; system-preferred method Fido2 | **Authenticator had also added push and codes**, both phishable. Removed | [Identity](../identity/README.md#2-a-passkey-on-an-account-with-no-methods) |
| `03-emergency-access-passkey-aaguid.png` | The passkey's AAGUID | The value Authenticator on Android reports. Graph records this passkey as attested; the profile does not require it, so an unattested passkey would also have been accepted | [Identity](../identity/README.md#2-a-passkey-on-an-account-with-no-methods) |

## Step 4 · Access rules (Les règles d'accès)

| Screenshot | What it shows | Why it matters | Page |
|---|---|---|---|
| `04-access-rules-no-policies-after-teardown.png` | Conditional Access policies page on its Get Started screen: no policies | The Day 15 policy was gone after the teardown, and nothing replaced it | [Identity](../identity/README.md#where-it-started) |
| `05-access-rules-security-defaults-off.png` | Security defaults **Disabled** | With no policy either, **nothing required MFA for users**, a month after Day 15 recorded the gap | [Identity](../identity/README.md#where-it-started) |
| `06-access-rules-lockout-warning.png` | "Don't lock yourself out!" with **Exclude current user** pre-selected | Microsoft's safeguard, wrong here: the emergency account is the safeguard, and the default would exempt the daily admin from MFA | [Identity](../identity/README.md#4-conditional-access) |
| `07-access-rules-whatif-test-user.png` | What If result for the test user: CA001 and CA003 apply, report-only | Simulated before anything was switched on. Inputs are listed on the page | [Identity](../identity/README.md#what-if-before-anything-went-on) |
| `08-access-rules-whatif-emergencyaccess-excluded.png` | What If result for the emergency account: no policy applies, reason **Users and groups** | The exclusion holds for all three policies | [Identity](../identity/README.md#what-if-before-anything-went-on) |
| `09-access-rules-report-only-sign-in.png` | Report-only results on a real Microsoft Edge sign-in: CA001 and CA003 Success, CA002 Not applied | **Found in the non-interactive log**, not the interactive one | [Identity](../identity/README.md#one-real-sign-in-still-in-report-only) |
| `10-access-rules-ca001-ca002-ca003-on.png` | CA001, CA002 and CA003, all three **On** | Switched on only after What If and the report-only sign-in agreed | [Identity](../identity/README.md#switched-on) |

## Step 5 · The workstation (Le poste de travail)

| Screenshot | What it shows | Why it matters | Page |
|---|---|---|---|
| `11-workstation-mdm-authority-none.png` | Choose MDM Authority set to **None** | **Error 80180003**, "not authorized to enroll". The tenant had never declared which service manages devices, so every enrolment was refused. The error blames the user; the user was never the problem | [Day 3](../day-guides/day-03-windows-install-entra-join-and-intune-enrolment.md#the-actual-cause) |
| `12-workstation-dyn-autopilot-devices.png` | `Dyn-Autopilot-Devices` with the lab VM as its member | **Profile stayed Not assigned** while it targeted `Dyn-Windows-Devices`: `deviceOSType` only matches enrolled devices. The ZTDid rule matches at registration | [Day 5](../day-guides/day-05-windows-autopilot.md#the-correct-rule) |
| `13-workstation-autopilot-apuserdrivenentrajoin.png` | Deployment profile `APUserDrivenEntraJoin`: User-Driven, Microsoft Entra joined | User-driven because self-deploying mode needs a physical TPM 2.0 | [Day 5](../day-guides/day-05-windows-autopilot.md#4-the-deployment-profile) |
| `14-workstation-corp-97322-encrypted.png` | `CORP-97322` in the Intune encryption report | The name comes from the profile's template `CORP-%RAND:5%`, proof the profile drove setup | [Rebuild](../rebuild/README.md#where-it-stands) |
| `15-workstation-cp-windows-compliant.png` | `CP-Windows` per setting: nine settings Compliant, 0 Not applicable | A Not applicable line was never checked. Zero means every check actually ran | [Rebuild](../rebuild/README.md#compliance) |
| `16-workstation-cfg-edge-smartscreen.png` | `edge://policy`: four SmartScreen policies true, Platform, Device, Mandatory, OK | The download switch belongs to Edge, so the Defender policy could not set it | [Rebuild](../rebuild/README.md#edge-smartscreen) |

## Step 6 · Check, don't assume (Vérifier, pas supposer)

| Screenshot | What it shows | Why it matters | Page |
|---|---|---|---|
| `17-checks-audit-exclusion-was-the-user.png` | PowerShell audit: all three policies exclude the **user** Emergency Access 01, no group | **What If could not show this.** The protected group did nothing until the policies named it | [Identity](../identity/README.md#the-exclusion-was-the-user-not-the-group) |
| `18-checks-audit-exclusion-fixed.png` | The same check after the fix: all three exclude the group `EmergencyAccess` | Fix verified by re-reading, not assumed | [Identity](../identity/README.md#the-exclusion-was-the-user-not-the-group) |
| `19-checks-audit-emergency-sign-ins.png` | Emergency account sign-ins with the method used | **The passkey sits on the error 50140 entry**, the "Stay signed in?" prompt, not on the success after it | [Identity](../identity/README.md#sign-ins-and-which-entry-carries-the-method) |
| `20-checks-audit-test-user-sign-ins.png` | Test user sign-ins, and app registrations holding client secrets | Windows Hello for Business explains CA001's report-only success. No client secrets on app registrations | [Identity](../identity/README.md#sign-ins-and-which-entry-carries-the-method) |
| `21-checks-bitlocker-portal-access-denied.png` | Portal: "You do not have access to view this BitLocker recovery key" | **Wrong error.** The account was Global Administrator. The portal blade failed, not the permission | [Lab log, Day 13](../LAB-LOG.md#day-13-the-portal-said-no-access-it-was-wrong) |
| `22-checks-bitlocker-graph-403.png` | Graph Explorer: 403 Forbidden on `recoveryKeys` | Graph needs `BitlockerKey.ReadBasic.All` and `BitlockerKey.Read.All` consented | [Lab log, Day 13](../LAB-LOG.md#day-13-the-portal-said-no-access-it-was-wrong) |
| `23-checks-bitlocker-graph-200-ok.png` | Graph Explorer: 200 OK on the same endpoint | The API returned what the portal refused. The interface is only a client of the API | [Lab log, Day 13](../LAB-LOG.md#day-13-the-portal-said-no-access-it-was-wrong) |
| `24-checks-bitlocker-three-recovery-keys.png` | Three recovery keys listed for one drive | Not a fault. Every encryption and every rotation escrows a new key and the old ones stay, which is why the recovery screen shows a Key ID | [Lab log, Day 13](../LAB-LOG.md#day-13-three-recovery-keys-one-disk) |
| `25-checks-defender-pua-protection-off.png` | Antivirus policy with **PUA Protection off** | **Insecure value enforced.** An explicit "off" overrides the device and still reports as applied. Fixed by setting it to block | [Lab log, Day 13](../LAB-LOG.md#day-13-the-antivirus-policy-was-enforcing-an-insecure-value) |

## Step 7 · Tear down and rebuild (Démolir et reconstruire)

Built in the first round, before the September teardown.

| Screenshot | What it shows | Why it matters | Page |
|---|---|---|---|
| `26-first-round-update-pin-24h2-deploys-25h2.png` | Policy `Feature-Pin-24H2`, Versions column **Windows 11, version 25H2** | **Name did not match behaviour.** The name was a label typed by a human; the Versions column is what the service does | [Lab log, Day 11](../LAB-LOG.md#day-11-a-policy-whose-name-did-not-match-what-it-deployed) |
| `27-first-round-firewall-merge-conflict.png` | Each merge setting listed twice as **Conflict**, Default Inbound Action Succeeded | **Policy did nothing.** An older profile set the merge switches to True, the new one to False, so Windows applied neither. Fixed by giving the firewall one owner | [Lab log, Day 14](../LAB-LOG.md#day-14-defaults-that-looked-like-success) |
| `28-first-round-ca-whatif-report-only.png` | What If: `CA-Require-Compliant-Device` under Policies that will apply, State Report-only | Verified with the simulator rather than a sign-in, because the admin account is excluded from the policy | [Lab log, Day 15](../LAB-LOG.md#day-15-conditional-access-and-the-multifactor-authentication-gap-it-created) |
| `29-first-round-7zip-installed.png` | 7-Zip 26.03 device install status: Installed on the lab VM | **False positive first.** `Test-Path` had returned True on the laptop, not the VM. Restarting the Intune Management Extension forced the install | [Lab log, Day 17](../LAB-LOG.md#day-17-test-path-returned-true-from-the-wrong-machine) |
| `30-first-round-app-protection-on-devices.png` | App protection policy assigned to `Dyn-Windows-Devices`: 1 devices, 0 users | **Protects nothing.** App protection targets users inside apps, not devices. Reassigned to `All-BYOD` | [Lab log, Day 19](../LAB-LOG.md#day-19-app-protection-policies-target-users-not-devices) |

## Outside the diagram · The October 2025 pipeline

| Screenshot | What it shows | Why it matters | Page |
|---|---|---|---|
| `31-pipeline-2025-secret-login.png` | October 2025: a pipeline signing in to Azure as a service principal with a client secret | The secret is stored in GitHub and handed to the run | [Workload identity](../identity/workload-identity-2025.md#the-pipeline-with-a-secret) |
| `32-pipeline-2025-secret-readable.png` | An untrusted step given `AZURE_CLIENT_SECRET`, printed as `***` | **Masking hides the value from the log, not from the code** | [Workload identity](../identity/workload-identity-2025.md#the-pipeline-with-a-secret) |
