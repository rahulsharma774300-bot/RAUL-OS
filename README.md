# RAUL-OS

## V2

RAUL.OS V2 is a sideloaded Android control layer built for explicit, user-issued commands.

### Included
- AccessibilityService UI control: open apps, tap visible text, type into non-password fields, scroll, swipe, back/home/recents, read visible screen text
- Voice command activity
- Floating draggable assistant orb
- Notification read/dismiss controls
- Local aliases, multi-step macros and local key/value memory
- Contacts dialer helper
- Media volume and playback controls
- Brightness, flashlight and Do Not Disturb helpers
- Screenshot capture/share hook for analysis in an AI app
- Shizuku detection/readiness boundary

### Privacy / safety behavior
- No passive accessibility-event logging
- Password fields are skipped for screen reading and typing
- Secure/DRM screens can block screenshots or automation
- Permissions must be explicitly enabled in Android settings

### Macro example
`open WhatsApp; wait 2; tap Radhika; wait 1; type I'll call you soon`

The V2 Android project lives in `RAUL_OS_V2/`.
