# Identity: emergency access, passkeys and Conditional Access

17 and 18 October 2026. Same tenant, same lab virtual machine (`CORP-97322`), same test user
(`lea.test`).

Day 15 ended on an open thread: switching off security defaults to use Conditional Access removed
the tenant's only multifactor authentication requirement, and nothing replaced it. This part starts
from that line.

---

## Where it started

Checked before changing anything, on 17 October.

**Conditional Access policies: none.** The teardown had removed the Day 15 policy and the rebuild
never recreated it.

![Conditional Access policies page showing the Get Started screen, no policies](../screenshots/17-identity-ca-no-policies.png)

**Security defaults: Disabled (not recommended).**

![Security defaults panel set to Disabled, with the warning that the organisation is vulnerable](../screenshots/18-identity-security-defaults-disabled.png)

With both off, nothing in the tenant's own configuration required multifactor authentication. The
only MFA left was the one Microsoft enforces on its admin portals. The gap recorded on Day 15 had
stayed open for a month, through the teardown and the rebuild.

---

## 1. An emergency access account, before any policy

Conditional Access can lock every administrator out, so the way back in comes first. Microsoft's
guidance ([Manage emergency access accounts](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-emergency-access)):
cloud-only on the `onmicrosoft.com` domain, Global Administrator as a permanent assignment,
phishing-resistant sign-in, excluded from every policy that blocks or restricts sign-in.

Built:

| Item | Value |
|---|---|
| Account | `emergency-access-01@labtenant.onmicrosoft.com`, cloud-only |
| Role | Global Administrator, assigned at creation |
| Group | `EmergencyAccess`, security group, assigned membership, **roles can be assigned to the group: Yes** |
| Sign-in methods | A password, generated and kept offline, and a passkey in Microsoft Authenticator. No other method |

The roles toggle on the group was my choice, not part of Microsoft's instructions for this group.
With it, only a Global Administrator, a Privileged Role Administrator or an owner of the group can
change who is in it. Without it, a Groups Administrator or User Administrator could add their own
account to the exclusion group and step outside every policy. It can only be set when the group is
created.

Where the lab falls short of the guidance:

| Microsoft says | The lab | Why |
|---|---|---|
| Two or more accounts | One | Lab |
| FIDO2 security key, stored in a safe | Passkey in Authenticator on my own phone | No hardware key |
| Not tied to an individual's phone | It is | Same reason |
| Different methods from the other admin accounts | Partly. Since 18 October the daily admin has Microsoft Authenticator and the emergency account a passkey, but the daily admin's older methods are still registered and not reviewed | See section 5 |
| Phishing-resistant methods | A password still exists | The account is excluded from the MFA policy below, and Microsoft's mandatory MFA covers the admin portals, not Microsoft 365 apps or Microsoft Graph. The password alone would open those. It is kept offline; closing this is on the list |
| A designated, secure workstation | My everyday laptop, in a private window | Lab |
| Alert on every sign-in of the account | Not built | The documented method uses Azure Monitor, which needs an Azure subscription |
| Test the account at least every 90 days | Tested 17 October, used for real 18 October | |

---

## 2. A passkey on an account with no methods

What Microsoft documents, in two places:

- The passkeys page: a user must have completed MFA in the last **five minutes** before registering
  a passkey
  ([Enable passkeys (FIDO2)](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-authentication-passkeys-fido2)).
  A new account has no method to complete it with.
- The Temporary Access Pass page: a one-time pass counts as strong authentication, and registration
  has to be finished within **10 minutes** of signing in with it. That page ties the limit to MFA
  enforcement during registration, not to the pass itself
  ([Temporary Access Pass](https://learn.microsoft.com/en-us/entra/identity/authentication/howto-authentication-temporary-access-pass)).

Temporary Access Pass was already enabled for all users. Issued one to the emergency account: one-time
use, one hour.

**The first attempt never asked for the pass.** On the phone, Android offered "NFC security key, USB
security key, use another device", and after cancelling, the sign-in page offered only "Face,
fingerprint, PIN or security key" or a password. The second attempt, a few minutes later, went
through Authenticator: **Add work or school account**, **Sign in**, **Use another account** in the
phone's account picker, the account name, then the pass prompt. Microsoft notes that a newly issued
pass can take a while to appear. I did not prove that was the cause.

The pass sign-in in the log:

![Sign-in authentication details: Temporary Access Pass, succeeded true](../screenshots/19-identity-tap-signin-auth-details.png)

**Authenticator registered more than the passkey.** The admin view showed two usable methods,
Microsoft Authenticator (push requests and one-time codes, on a Google Pixel 7) and the passkey, with
push notification as the default sign-in method. Push and codes can be phished; a passkey cannot.
Deleted the Authenticator method and the spent pass. What remains:

![Emergency account: one usable method, Passkey, system-preferred MFA method Fido2](../screenshots/20-identity-emergency-passkey-only.png)

The passkey's details show the AAGUID that Authenticator on Android reports. Microsoft Graph lists
its attestation level as `attested` (section 5), although the profile below does not require
attestation.

![AAGUID de1e552d-db1d-4423-a619-566b625cdc84](../screenshots/21-identity-passkey-aaguid.png)

**The tenant's passkey settings are the loosest available.** Passkey profiles were already on. The
default profile covers all users with attestation not enforced, device-bound and synced passkeys
allowed, and no key restrictions. A stricter profile for the emergency group alone would restrict
nothing: the portal states that users can register a passkey "if they are scoped into ANY assigned
passkey profile". Tightening the default is a decision for every user, so it is listed below, not
changed here. SMS and voice call were already disabled as methods.

---

## 3. Testing the emergency account

Microsoft's guidance is to test it, not only create it. 17 October: private browser window on the
host, Microsoft Entra admin center, the account name, then the passkey through a QR code scanned
with the phone. Signed in.

The entry I opened in the portal, Azure Portal, Success, had an empty Authentication Details tab.
The method is logged on the entry three seconds earlier, which I found through Microsoft Graph
(section 5): error **50140** with **Passkey (device-bound)**, succeeded. 50140 is the "Stay signed
in?" prompt. The passkey step is recorded on that interrupted entry, not on the success after it.

---

## 4. Conditional Access

Three policies, created in report-only. Each was meant to exclude the `EmergencyAccess` group;
section 5 shows what they actually excluded at first.

| Policy | Users | Resources and conditions | Control |
|---|---|---|---|
| `CA001-Require-MFA-All-Users` | All users | All resources | Require multifactor authentication |
| `CA002-Block-Legacy-Authentication` | All users | All resources, client apps: Exchange ActiveSync and other clients | Block access |
| `CA003-Require-Compliant-Device-Windows` | `lea.test` | All resources, device platform: Windows | Require device to be marked as compliant |

**Why CA003 covers one user.** I administer the tenant from the host laptop, which is not enrolled
in Intune. Applied to all users and switched on, CA003 would block me from the admin portals. The
test user signs in on `CORP-97322`, which is compliant. Sign-ins from any other platform, Android,
iOS, macOS, Linux or unknown, are outside CA003.

**The lock-out warning.** Creating CA001 for all users brings up "Don't lock yourself out!" with
**Exclude current user** already selected. That default is Microsoft's safeguard against locking
yourself out, and in a tenant without an emergency account it is the sensible choice. Here the
emergency account is the safeguard, and accepting the default would have left the daily Global
Administrator outside the MFA policy. Chose "I understand that my account will be impacted by this
policy" instead. I assumed the daily admin account could complete MFA, because the portals had been
asking for it. Section 5 shows it could not on a fresh sign-in.

![Don't lock yourself out warning with Exclude current user pre-selected](../screenshots/22-identity-ca-lockout-warning.png)

### What If, before anything went on

Inputs: the test user, Office 365 Exchange Online, Windows, browser. Result: CA001 and CA003 apply,
CA002 does not, because a browser is not a legacy client.

![What If result for the test user: CA001 and CA003 will apply, both report-only](../screenshots/23-identity-whatif-test-user.png)

Same inputs with the emergency account: no policy applies, and each one gives the same reason,
**Users and groups**.

![What If result for the emergency account: all three policies will not apply, reason Users and groups](../screenshots/24-identity-whatif-emergency-excluded.png)

That reason is true whether the policy excludes the account itself or a group it belongs to. What If
cannot tell the two apart. Section 5 shows why that mattered.

### One real sign-in, still in report-only

18 October, evening: started the VM, signed in as the test user, opened Outlook on the web in Edge.

The **interactive** sign-in log held one entry, **Windows Sign In**, with the report-only tab reading
"Not applicable". The Edge sign-ins from that session were on the **non-interactive** tab. The
report-only tab of one Microsoft Edge entry:

![Report-only results on a Microsoft Edge sign-in: CA001 Success, CA003 Success, CA002 Not applied](../screenshots/25-identity-reportonly-edge-signin.png)

The same split as What If: CA001 and CA003 evaluated and satisfied, CA002 not applied. CA001 was
satisfied because the test user had signed in to Windows with Windows Hello for Business, which
counts as multifactor: a Hello sign-in gives the primary refresh token an MFA claim, which later
app tokens carry
([Primary Refresh Token](https://learn.microsoft.com/en-us/entra/identity/devices/concept-primary-refresh-token#when-does-a-prt-get-an-mfa-claim)).
Section 5 shows the method. Two other Microsoft Edge entries in the same list
have status Failure; they are on the list below.

### Switched on

18 October, after the report-only check:

![Conditional Access policies: CA001, CA002 and CA003, all three On](../screenshots/26-identity-ca-policies-on.png)

---

## 5. Checking it with PowerShell

The portal shows one object at a time. [identity-audit.ps1](identity-audit.ps1) reads the same
settings through Microsoft Graph in one pass and changes nothing: the Conditional Access policies,
the emergency account's methods, groups and roles, recent sign-ins with the method used, and app
registrations holding client secrets. It needs only the `Microsoft.Graph.Authentication` module.

### First, the daily admin could not sign in

Running the script needed a fresh sign-in as the daily Global Administrator. The MFA prompt offered a
passkey or a verification code, and I had neither for that account. The browser session was still
valid. Microsoft's Temporary Access Pass page says the admin roles that issue passes can do it for
other users, "except themselves", so the pass had to come from another account.

So, 18 October: signed in as the emergency account with its passkey, issued the daily admin a
one-time pass, signed in with it and registered Microsoft Authenticator. This was the first real use
of the emergency account, the day after it was built.

### The exclusion was the user, not the group

The first run showed no group excluded from any policy, and the script had no column for excluded
users, the same blind spot What If has. With that column added, the second run:

![Script output: all three policies exclude the user Emergency Access 01, and no group](../screenshots/29-identity-audit-exclusion-was-the-user.png)

All three policies excluded **the user Emergency Access 01**. None excluded the `EmergencyAccess`
group. In the policy picker the user and the group have almost the same name, and the user was
picked. The account was still excluded, so What If passed. But the protected group did nothing:
Conditional Access never looked at it, and a fourth policy would only protect the account if someone
remembered the user.

Changed all three policies to exclude the group. The next run:

![Script output: all three policies now exclude the group EmergencyAccess](../screenshots/30-identity-audit-exclusion-fixed.png)

The same output shows the emergency account holding a password and one passkey, `fido2`, with
attestation level `attested`, its Global Administrator role, and one other group, blacked out
because its name is the tenant's.

### Sign-ins, and which entry carries the method

![Script output: emergency account sign-ins with methods, including Passkey (device-bound) on two error 50140 entries](../screenshots/31-identity-audit-emergency-signins.png)

- **17 October, 08:01 UTC:** Temporary Access Pass, logged under Microsoft Authentication Broker
  when the account was added to Authenticator.
- **17 October, 08:14 UTC:** the test sign-in. Passkey on the 50140 entry, success three seconds
  later with no method listed.
- **18 October, 19:59 UTC:** the same pattern, for the real use, with Conditional Access
  **notApplied**. At that point the policies still excluded the user, and of the three only CA001
  could have applied to this sign-in. So this shows the user exclusion holding under enforcement.
  The group exclusion has not yet been tested by a real sign-in.

![Script output: the test user's sign-ins, Windows Hello for Business on 18 October, and no app registrations holding client secrets](../screenshots/32-identity-audit-test-user-signins.png)

- **Test user:** the 18 October Windows sign-in used **Windows Hello for Business**. That explains
  the MFA claim behind CA001's report-only success.
- **App registrations holding client secrets:** none. The check reads client secrets on app
  registrations only, not certificates or credentials on service principals.

### The script stopped silently three times

The first three runs stopped partway, with no error on screen and no reason given. Each check now
runs inside its own error handler, prints what went wrong if it fails, and the script ends with an
explicit `=== Done ===`. The fourth run went through all four checks and none failed. I did not find
out why the earlier runs stopped.

---

## What I would check first next time

- **The tenant-wide MFA state before anything else.** Security defaults and the policy list take a
  minute to read, and here they showed a month-old gap.
- **What a policy actually excludes, read back after saving.** The picker shows a user and a group
  with almost the same name, and What If gives the same answer for both.
- **That the daily admin can complete MFA on a fresh sign-in** before anything depends on it.
- **The pre-selected option in every confirmation box.** It is right for the general case, which is
  not always this one.
- **Which log tab a sign-in lands on.** Edge sign-ins on a joined device were non-interactive and
  easy to miss.

---

## Still to do

- **Audits:** audit log review, Secure Score identity recommendations, Purview audit search.
- **Support scenarios:** an admin who cannot complete MFA (partly done on 18 October: the pass and
  a new method; still to do: removing the old methods and revoking sessions), a blocked user read
  from the sign-in log, a new starter, a leaver, shared mailbox access.
- **More Graph checks:** MFA registration status for all users, admin role members.
- **Open from this part:** the emergency account's password, a real sign-in that tests the group
  exclusion, a phishing-resistant method for the daily admin, the two failed Edge sign-ins, why the
  first script runs stopped.
- **Tighten the default passkey profile**, add a second emergency account, and an alert on its use.
- **Not in the lab:** on-premises Active Directory and Entra Connect. No domain controller.

An earlier piece of identity work, from October 2025, on the non-human side: a pipeline that signed
in with a client secret, and the federated credential set up to replace it.
[Workload identity, October 2025](workload-identity-2025.md)
