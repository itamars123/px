#!/usr/bin/env python3
"""Builds StealATreasure.rbxlx from src/ without needing Rojo.

Mirrors default.project.json:
  src/ReplicatedFirst            -> ReplicatedFirst            (*.client.luau = LocalScript)
  src/ReplicatedStorage/Shared   -> ReplicatedStorage.Shared   (ModuleScripts)
  src/ServerScriptService        -> ServerScriptService        (*.server.luau = Script)
  src/StarterPlayerScripts/Client-> StarterPlayer.StarterPlayerScripts.Client
*.txt files become StringValues (used for the ProfileStore licence).

Usage:  python3 tools/build_place.py
"""
import os
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "StealATreasure.rbxlx")
_ref = 0


def ref():
    global _ref
    _ref += 1
    return f"RBX{_ref:08X}"


def cdata(src: str) -> str:
    return "<![CDATA[" + src.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, children="", source=None, extra=""):
    props = f'<string name="Name">{escape(name)}</string>'
    if source is not None:
        props += f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
    props += extra
    return f'<Item class="{cls}" referent="{ref()}"><Properties>{props}</Properties>{children}</Item>\n'


def strip(name, *suffixes):
    for s in suffixes:
        if name.endswith(s):
            return name[: -len(s)]
    return name


def build_dir(path):
    out = ""
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            out += item("Folder", entry, build_dir(full))
            continue
        text = open(full, encoding="utf-8").read()
        if entry.endswith((".server.luau", ".server.lua")):
            out += item("Script", strip(entry, ".server.luau", ".server.lua"), source=text)
        elif entry.endswith((".client.luau", ".client.lua")):
            out += item("LocalScript", strip(entry, ".client.luau", ".client.lua"), source=text)
        elif entry.endswith((".luau", ".lua")):
            out += item("ModuleScript", strip(entry, ".luau", ".lua"), source=text)
        elif entry.endswith(".txt"):
            out += item("StringValue", strip(entry, ".txt"), extra=f'<string name="Value">{escape(text)}</string>')
    return out


def main():
    src = os.path.join(ROOT, "src")
    body = ""
    body += item("ReplicatedFirst", "ReplicatedFirst", build_dir(os.path.join(src, "ReplicatedFirst")))
    body += item("ReplicatedStorage", "ReplicatedStorage", item("Folder", "Shared", build_dir(os.path.join(src, "ReplicatedStorage", "Shared"))))
    body += item("ServerScriptService", "ServerScriptService", build_dir(os.path.join(src, "ServerScriptService")))
    body += item(
        "StarterPlayer",
        "StarterPlayer",
        item("StarterPlayerScripts", "StarterPlayerScripts", item("Folder", "Client", build_dir(os.path.join(src, "StarterPlayerScripts", "Client")))),
    )
    body += item("Workspace", "Workspace", extra='<bool name="StreamingEnabled">false</bool>')
    # Future lighting = real-time shadows from every light, reflections and bloom
    body += item(
        "Lighting",
        "Lighting",
        extra='<token name="Technology">4</token><bool name="GlobalShadows">true</bool>'
        '<float name="EnvironmentDiffuseScale">0.8</float><float name="EnvironmentSpecularScale">1</float>',
    )
    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        + body
        + "</roblox>\n"
    )
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    print("Wrote", OUT)


if __name__ == "__main__":
    main()
