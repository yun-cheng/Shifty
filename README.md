Shifty was made to expand the capabilities of the built in Night Shift feature in macOS. You can disable Night Shift for specific apps, websites, and custom time periods. It also provides easy access to a slider to fine tune your color temperature. With Shifty, Night Shift becomes a power user feature!

<img src='docs/en/images/shifty-screenshot-large.png' width=70%>

Shifty is customizable! Make it easier to toggle Night Shift with Quick Toggle or set dark mode based on the schedule. For common Shifty actions, you can set global keyboard shortcuts.

<img src="docs/en/images/prefs-general-screenshot-shadow.png" width=60%/>

### System requirements:
* macOS 10.12.4 or later
* System meets the [requirements for Night Shift](https://support.apple.com/en-us/HT207513#requirements)
* Website shifting supports Safari, Chrome, and Vivaldi.

<br>
Shifty is free and open source, licensed under GPLv3. Feel free to make a pull request!

If you'd like to help translate Shifty into other languages, you can contribute [here](https://shifty.natethompson.io/translate).

---

## Custom fork: versioning

This fork uses **CalVer** (Calendar Versioning): `YYYY.MM.DD.MICRO`

- `2026.06.21.1` — first build on June 21, 2026
- `2026.06.21.2` — second build on the same day
- `2026.06.22.1` — first build on June 22, 2026

To publish a new release:

```bash
TODAY=$(date +%Y.%m.%d)
NEXT=$(git tag -l "$TODAY.*" | wc -l | tr -d ' ')
NEXT=$((NEXT + 1))
git tag "$TODAY.$NEXT" -m "Release $TODAY.$NEXT"
git push origin "$TODAY.$NEXT"
```

GitHub Actions will auto-build the DMG and create a Release.
