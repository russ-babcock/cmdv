# CmdV — 3A "Paper"

app-icon/    CmdV-1024/512/256/128.png — squircle at 81.6% of canvas, transparent margin (macOS convention)
             CmdV-app-icon.svg — vector source
menubar/     CmdV-menubarTemplate-18 / 18@2x / 18@3x.png — black + alpha, transparent
             CmdV-menubarTemplate.svg — vector source

Menubar: name the asset "CmdVmenubarTemplate" (or set isTemplate = true) so macOS
inverts it for dark mode and tints it when the menu item is highlighted.

Build the .icns:
  mkdir CmdV.iconset && cp app-icon/CmdV-1024.png CmdV.iconset/icon_512x512@2x.png  # etc.
  iconutil -c icns CmdV.iconset

Note: the command glyph is live text in both SVGs (Helvetica Neue). Convert it to
outlines in a vector editor before shipping the SVG; the PNGs already have it baked.
