# CmdV icons — menubar 6A + app icon 8H

app-icon/   CmdV-1024…16.png — Ink plate, squircle at 81.6% of canvas, transparent margin
            CmdV-app-icon.svg — vector source
            Art at 78% of the plate: gradient-filled ⌘, cyan lead chevron (#4fbde6),
            trail chevron in 50% white.
menubar/    CmdVmenubarTemplate-18 / 18@2x / 18@3x.png — black + alpha, transparent
            CmdVmenubarTemplate.svg — vector source
            Single chevron, no trail. Name the asset "CmdVmenubarTemplate" (or set
            isTemplate = true) so macOS inverts it for dark mode and tints it when
            the menu item is highlighted.

Build the .icns:
  mkdir CmdV.iconset
  cp app-icon/CmdV-1024.png CmdV.iconset/icon_512x512@2x.png   # etc. for each size
  iconutil -c icns CmdV.iconset

The ⌘ is live Helvetica text in both SVGs — convert to outlines before shipping.
The PNGs already have it baked.
