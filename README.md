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

## Custom fork: what's different

This fork adds support for **external displays** and **fullscreen-aware gamma control**.

### External display gamma ramp

macOS Night Shift only works on built-in Retina displays. This fork uses `CGSetDisplayTransferByTable` gamma ramp to apply the same color temperature effect to any external monitor — tested on **BenQ D43-720 5K**.

- Three calibrated presets: 5500K (cool), 4200K (neutral-warm), 3400K (warmest)
- Default: 4200K
- Gamma tables calibrated from live f.lux readings

### Fullscreen-aware gamma

When any app enters fullscreen mode, Night Shift + gamma ramp are automatically disabled, then restored when you exit fullscreen. This uses the Window Server API (`CGWindowListCopyWindowInfo`), so no Accessibility permission is needed.

### Sane defaults

Unlike the original, this fork enables the most useful preferences out of the box on a fresh install:

| Preference | Default |
|---|---|
| Launch at login | On |
| Set icon according to Night Shift | On |
| Disable in fullscreen | On |
| Night Shift on first launch | On |

### Calendar versioning

Releases use `YYYY.MM.DD.MICRO` (CalVer). Each tagged release auto-builds a DMG via GitHub Actions.
