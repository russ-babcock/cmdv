#!/usr/bin/env python3
"""Insert (or replace) one release in the Sparkle appcast.

Sparkle's own `generate_appcast` regenerates the whole feed from a directory of
archives, which assumes every archive is reachable under one URL prefix. Ours
aren't: each release's zip lives under its own GitHub release tag. So this
writes a single <item> instead, leaving previously published items untouched —
older versions keep working download links forever.

Usage:
  update_appcast.py FEED --version BUILD --short-version 0.2.0 --url URL \
      --length BYTES --signature SIG [--min-system 26.0] [--notes TEXT] [--link URL]
"""

import argparse
import os
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from email.utils import format_datetime

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)


def sparkle(tag: str) -> str:
    return f"{{{SPARKLE_NS}}}{tag}"


EMPTY_FEED = """<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>CmdV</title>
    <link>https://russ-babcock.github.io/cmdv/appcast.xml</link>
    <description>Updates for CmdV, a clipboard manager for macOS.</description>
    <language>en</language>
  </channel>
</rss>
"""


def load_channel(path: str):
    if not os.path.exists(path) or os.path.getsize(path) == 0:
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(EMPTY_FEED)
    tree = ET.parse(path)
    channel = tree.getroot().find("channel")
    if channel is None:
        sys.exit(f"error: {path} has no <channel> element")
    return tree, channel


def build_item(args) -> ET.Element:
    item = ET.Element("item")
    ET.SubElement(item, "title").text = args.short_version
    ET.SubElement(item, "pubDate").text = format_datetime(datetime.now(timezone.utc))
    ET.SubElement(item, sparkle("version")).text = args.version
    ET.SubElement(item, sparkle("shortVersionString")).text = args.short_version
    ET.SubElement(item, sparkle("minimumSystemVersion")).text = args.min_system
    if args.link:
        ET.SubElement(item, "link").text = args.link
    if args.notes:
        ET.SubElement(item, "description").text = args.notes

    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", args.url)
    enclosure.set("length", str(args.length))
    enclosure.set("type", "application/octet-stream")
    enclosure.set(sparkle("edSignature"), args.signature)
    return item


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("feed")
    parser.add_argument("--version", required=True, help="CFBundleVersion (build number)")
    parser.add_argument("--short-version", required=True, help="CFBundleShortVersionString")
    parser.add_argument("--url", required=True)
    parser.add_argument("--length", required=True)
    parser.add_argument("--signature", required=True)
    parser.add_argument("--min-system", default="26.0")
    parser.add_argument("--notes", default="")
    parser.add_argument("--link", default="")
    args = parser.parse_args()

    tree, channel = load_channel(args.feed)

    # Re-running a release for the same build replaces its item rather than
    # publishing a duplicate that Sparkle would see as two identical updates.
    for existing in channel.findall("item"):
        version = existing.find(sparkle("version"))
        if version is not None and version.text == args.version:
            channel.remove(existing)

    item = build_item(args)
    first_item = channel.find("item")
    if first_item is None:
        channel.append(item)
    else:
        channel.insert(list(channel).index(first_item), item)

    ET.indent(tree, space="  ")
    tree.write(args.feed, encoding="utf-8", xml_declaration=True)
    print(f"appcast: wrote {args.short_version} ({args.version}) to {args.feed}")


if __name__ == "__main__":
    main()
