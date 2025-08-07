# pinpad_screenlock_plugin

A small plugin to enable locking the screen of KOReader with a PIN code.

This work was originally based on the work of yogi81 and their plugin `screenlock_koreader_plugin`.

![alt text][screenshot]

[screenshot]: https://github.com/Lena2309/pinpad_screenlock_plugin/pinpad-screenshot.png "PIN Pad Screenshot"

## Setup

1. Put `pinpadlockscreen.koplugin` into the `kodreader/plugins` directory.
2. Put `lock.svg` or your own icon (with this specific name) into the `koreader/resources/icons/mdlight` directory.
3. Change the hardcoded password in config.lua.

## Future work

For now, the PIN pad will appear directly when the device is unlocked.
Which means the document's page you were on before locking your device will be visible.
I plan on making the PIN pad appear on the sceensaver background.

I also plan on adding a menu entry where you could activate or deactivate the PIN lock and change the PIN code from there.

Finally, I plan on adding a 3 tries limit, which if attained will activate a timeout.

**Note:** I do not know when I'll be implementing these features. Also, my work could probably be optimized so I'm open to any new ideas and remarks.

:)
