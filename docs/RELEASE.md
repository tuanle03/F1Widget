# Release workflow

The app uses [Sparkle](https://sparkle-project.org) for auto-updates. New releases need to be signed with the project's EdDSA private key, then published to the appcast feed.

## One-time setup

### 1. Add Sparkle to the Xcode project (already done if `Sparkle` shows in SPM)

File → Add Package Dependencies… → `https://github.com/sparkle-project/Sparkle.git` → add to **F1Widget** target only.

### 2. Generate the EdDSA key pair (one time, ever)

Once Sparkle has been resolved by SPM, its bundled tools are inside DerivedData. Run:

```bash
~/Library/Developer/Xcode/DerivedData/F1Widget-*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
```

This stores the **private** key in the macOS Keychain (item name `https://sparkle-project.org`, account `ed25519`) and prints the **public** key to stdout. Save the public key — it goes into the app's Info.plist.

### 3. Add Info.plist keys (via Xcode UI)

Target **F1Widget** → **Build Settings** → search for `Info.plist` → expand **Info.plist Values**:

- Add a custom user-defined setting `INFOPLIST_KEY_SUFeedURL` = `https://tuanle03.github.io/F1Widget/appcast.xml`
- Add `INFOPLIST_KEY_SUPublicEDKey` = `<paste the public key from step 2>`

(Or add them directly to a custom Info.plist file if you'd rather.)

### 4. Enable GitHub Pages

On GitHub → repo Settings → **Pages** → Source: **Deploy from a branch**, Branch: `main`, Folder: `/docs`. After a minute, `appcast.xml` will be live at `https://tuanle03.github.io/F1Widget/appcast.xml`.

## Per-release workflow

1. **Bump the version** in Xcode → Target F1Widget → General → Identity:
   - Marketing Version: `1.3`
   - Build (CFBundleVersion): `3` (monotonic)

2. **Build a fresh Release archive**:
   - Product → Archive
   - Organizer → Distribute App → Custom → Copy App → save to `~/Desktop/F1Widget-export-vX/`

3. **Build the DMG**:
   ```bash
   STAGING=$(mktemp -d)
   cp -R "$HOME/Desktop/F1Widget-export-v1.3/F1Widget.app" "$STAGING/"
   ln -s /Applications "$STAGING/Applications"
   hdiutil create -volname "F1Widget" -srcfolder "$STAGING" \
     -ov -format UDZO ~/projects/F1Widget/F1Widget.dmg
   rm -rf "$STAGING"
   ```

4. **Sign the DMG with the EdDSA key**:
   ```bash
   ~/Library/Developer/Xcode/DerivedData/F1Widget-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update ~/projects/F1Widget/F1Widget.dmg
   ```

   Output looks like:
   ```
   sparkle:edSignature="<long_base64>" length="<bytes>"
   ```
   Copy both values.

5. **Add an entry to `docs/appcast.xml`**:

   ```xml
   <item>
       <title>F1Widget 1.3</title>
       <pubDate>Thu, 21 May 2026 12:00:00 +0700</pubDate>
       <sparkle:version>3</sparkle:version>
       <sparkle:shortVersionString>1.3</sparkle:shortVersionString>
       <sparkle:minimumSystemVersion>26.3</sparkle:minimumSystemVersion>
       <description><![CDATA[
           <h3>What's new in 1.3</h3>
           <ul><li>Bullet point 1</li></ul>
       ]]></description>
       <enclosure
           url="https://github.com/tuanle03/F1Widget/releases/download/v1.3/F1Widget.dmg"
           sparkle:edSignature="<paste>"
           length="<paste>"
           type="application/octet-stream" />
   </item>
   ```

6. **Push code + create a GitHub Release**:
   ```bash
   git add docs/appcast.xml
   git commit -m "Release v1.3"
   git push
   git tag v1.3
   git push --tags
   ```

   On github.com → Releases → Draft a new release → tag `v1.3` → upload `F1Widget.dmg` as asset → Publish.

7. **Verify**: open an older copy of F1Widget. Within an hour (or trigger "Check for updates now" in Settings) it should detect and offer the new version.

## Notes

- Sparkle's signature **does not** replace Apple notarization. The app still requires `xattr -dr com.apple.quarantine` for first-run on a new machine (covered in the main README).
- If the public key in Info.plist ever changes, **every** prior installation will refuse to update — keep the same key for life.
