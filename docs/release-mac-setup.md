# Release Mac setup

How to prepare a Mac to release Downtab: sign with Developer ID, notarize, sign updates for Sparkle and publish on
GitHub. The release itself (`make ship`, `make release`) is described in [`releasing.md`](releasing.md).

The team is already enrolled in the Apple Developer Program (doubleloop srl, Team ID `49CP6UC6KC`), and the Sparkle
key and the notary key already exist (#58, #68). This guide is for a developer setting up another Mac.

Each step says what to do and how to verify it. Run the commands from the root of the repo.

## What you need

- Access to the team password manager: it holds the notary key and the Sparkle key backup.
- The Account Holder of the Apple developer team: only they can create a Developer ID certificate.
- Push permission on `doubleloop-io/downtab`.

## 1. Toolchain and clone

Install Xcode or the Command Line Tools with Swift 6.4 and the macOS 27 SDK, and select it with `xcode-select`. Clone the
repo in full: `make bundle` refuses a shallow clone, because the build number is the commit count.

Verify:

```sh
xcrun swift --version                   # Apple Swift version 6.4.x
xcrun --show-sdk-version                # 27.x
git rev-parse --is-shallow-repository   # false
make test                               # passes
```

## 2. Apple's intermediate certificate

A Developer ID identity is valid only with Apple's intermediate "Developer ID Certification Authority (G2)" in the
keychain. Download it and open it, adding it to the login keychain:

```sh
curl -fLO https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer
open DeveloperIDG2CA.cer
```

Verify:

```sh
security find-certificate -c "Developer ID Certification Authority" -a | grep '"labl"'
```

prints `"labl"<blob>="Developer ID Certification Authority"`.

## 3. Certificate Signing Request

Each releaser has their own Developer ID certificate. The identity name (`Developer ID Application: doubleloop srl
(49CP6UC6KC)`) stays the same, and the app's designated requirement names only the Team ID, not a certificate: the
Makefile, the users' Accessibility grant and Sparkle's update check accept a release signed by any releaser.

A Certificate Signing Request (CSR) is the file you send Apple to get a certificate: it holds your public key and the
name you give it, signed with your private key. Creating it generates the key pair in your login keychain. The private
key never leaves this Mac: Apple issues the certificate for the public key.

1. Open Keychain Access (`open -a "Keychain Access"`).
2. Menu Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority.
3. User Email Address: your email. Common Name: a name for the key, e.g. `Your Name Developer ID`. CA Email Address:
   empty.
4. Choose "Saved to disk", then Continue, and save the `.certSigningRequest` file.

Verify:

```sh
openssl req -in <file>.certSigningRequest -noout -verify -subject
```

prints `Certificate request self-signature verify OK` (Homebrew OpenSSL 3) or `verify OK` (the system's LibreSSL),
then your email and Common Name.

## 4. Your own Developer ID certificate

1. Send the `.certSigningRequest` file to the Account Holder. At developer.apple.com → Certificates → `+`, they select
   Developer ID Application, Continue, and, if asked for the Developer ID Certificate Intermediary, choose G2 Sub-CA.
   They upload the CSR and send you the resulting `.cer`. A team can have at most five Developer ID Application
   certificates at a time.
2. Open the `.cer`: it joins the private key in the login keychain, forming the signing identity. The private key
   exists only on the Mac that made the CSR: open the `.cer` there.
3. Back up the identity: in Keychain Access, export the certificate with its private key as `.p12`, with a password,
   and store both in the password manager under your name.

Verify:

```sh
security find-identity -v -p codesigning
```

lists `Developer ID Application: doubleloop srl (49CP6UC6KC)`. `-v` shows valid identities only: if it is missing,
`security find-identity -p codesigning` shows all of them, and step 2 is the first thing to check.

## 5. Notary credentials

Notarization uses the team's App Store Connect API key. Take the `.p8` file, the Key ID and the Issuer ID from the
password manager and store them in a keychain profile:

```sh
xcrun notarytool store-credentials downtab-notary \
  --key AuthKey_<KEY_ID>.p8 --key-id <KEY_ID> --issuer <ISSUER_ID>
```

Then delete the `.p8` from the disk: the keychain profile holds the credentials now.

Verify:

```sh
xcrun notarytool history --keychain-profile downtab-notary
```

succeeds.

## 6. Sparkle key

Every update is signed with the one EdDSA key whose public half is `SUPublicEDKey` in `App/Info.plist`. Do not generate
a new one: the release preflight refuses a key that is not `SUPublicEDKey`. Resolve the package to get Sparkle's tools,
then import the backup file `downtab-sparkle-key` from the password manager:

```sh
swift package resolve
.build/artifacts/sparkle/Sparkle/bin/generate_keys -f downtab-sparkle-key --account io.doubleloop.downtab
rm downtab-sparkle-key
```

Verify:

```sh
.build/artifacts/sparkle/Sparkle/bin/generate_keys -p --account io.doubleloop.downtab
/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" App/Info.plist
```

print the same key. macOS asks once per tool (`generate_keys`, `sign_update`) to use the key: answer `Always Allow`.
Step 9 uses both tools, so the dialogs show there and never halfway through a release.

## 7. GitHub CLI

`make release` publishes the release and dispatches the website deploy with `gh`.

```sh
gh auth login
```

Verify:

```sh
gh auth status
gh api repos/doubleloop-io/downtab --jq .permissions.push   # true
```

## 8. Accessibility

`make smoke` posts synthetic key events, so the terminal needs the Accessibility permission. On this Mac every build
signs with the Developer ID (no `make setup-signing` needed), so a grant to `make run` also covers the installed
release.

1. System Settings → Privacy & Security → Accessibility: enable your terminal app.
2. `make run`, then enable Downtab in the same list.

Verify:

```sh
make smoke   # prints smoke ok
```

## 9. Full check

`make notarize-check` runs the release preflight (identity, notary profile, Sparkle key, `gh` permissions), then builds,
notarizes and staples `build/Downtab.dmg` and signs it for Sparkle, as `make release` does. It tags and publishes
nothing.

Verify:

```sh
make notarize-check   # prints release preflight ok and finishes without errors
```

The Mac is ready to release.

## Renewal

Developer ID certificates issued from G2 are valid for one year and must be renewed annually. See when yours expires:

```sh
security find-certificate -c "Developer ID Application: doubleloop srl" -p | openssl x509 -noout -enddate
```

Before it does, repeat steps 3 and 4 and back up the new `.p12`. Releases signed while the certificate was valid keep
installing and running after it expires; signing new releases needs the new certificate. Users keep their
Accessibility grant: the designated requirement names the Team ID, which does not change.

## When a releaser stops releasing

- Their Developer ID certificate: Apple states that "any Developer ID app signed with a certificate that has been
  revoked can no longer be installed nor launch if it's already installed". Revoking it therefore breaks every release
  they signed, for every user. Left alone, it expires within a year.
- The notary key is shared. Revoke it in App Store Connect → Users and Access → Integrations → Team Keys (Account
  Holder or Admin; a revoked key cannot be reinstated), create a new one, store the new `.p8`, Key ID and Issuer ID in
  the password manager, and repeat step 5 on every release Mac.
- The Sparkle key is shared. Sparkle validates an update against the installed copy's `SUPublicEDKey`, so whoever
  imported the key can still sign updates that installed copies accept; shipping them also needs publishing on this
  repo, where `SUFeedURL` points. Sparkle can rotate the key with an update that changes the EdDSA key but keeps the
  Developer ID signature of the same team (Sparkle documentation, "Rotating signing keys").
