#!/usr/bin/env python3
"""Builds StealATreasure.rbxlx from src/ without needing Rojo.

Mirrors default.project.json:
  src/shared  -> ReplicatedStorage.Shared          (ModuleScripts)
  src/server  -> ServerScriptService.Server        (*.server.lua = Script)
  src/client  -> StarterPlayer.StarterPlayerScripts.Client (*.client.lua = LocalScript)

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


def build_dir(path):
    out = ""
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            out += item("Folder", entry, build_dir(full))
        elif entry.endswith(".lua"):
            src = open(full, encoding="utf-8").read()
            if entry.endswith(".server.lua"):
                out += item("Script", entry[: -len(".server.lua")], source=src)
            elif entry.endswith(".client.lua"):
                out += item("LocalScript", entry[: -len(".client.lua")], source=src)
            else:
                out += item("ModuleScript", entry[: -len(".lua")], source=src)
    return out


def main():
    src = os.path.join(ROOT, "src")
    body = ""
    body += item("ReplicatedStorage", "ReplicatedStorage", item("Folder", "Shared", build_dir(os.path.join(src, "shared"))))
    body += item("ServerScriptService", "ServerScriptService", item("Folder", "Server", build_dir(os.path.join(src, "server"))))
    body += item(
        "StarterPlayer",
        "StarterPlayer",
        item("StarterPlayerScripts", "StarterPlayerScripts", item("Folder", "Client", build_dir(os.path.join(src, "client")))),
    )
    body += item("Workspace", "Workspace", extra='<bool name="StreamingEnabled">false</bool>')
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
