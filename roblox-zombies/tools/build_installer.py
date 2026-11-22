"""Bundle the scripts in src/ into one Install.lua you paste into Roblox Studio's Command Bar."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILES = [  # (class, name, parent expression, source file)
    ("ModuleScript", "ZombieConfig", "game:GetService('ReplicatedStorage')", "src/ReplicatedStorage/ZombieConfig.lua"),
    ("ModuleScript", "ZombieMapBuilder", "game:GetService('ServerScriptService')", "src/ServerScriptService/ZombieMapBuilder.lua"),
    ("Script", "ZombieServer", "game:GetService('ServerScriptService')", "src/ServerScriptService/ZombieServer.server.lua"),
    ("LocalScript", "ZombieClient", "game:GetService('StarterPlayer'):WaitForChild('StarterPlayerScripts')", "src/StarterPlayerScripts/ZombieClient.client.lua"),
]
EQ = "=" * 8

out = [
    "-- Zombie Waves installer: paste ALL of this into Roblox Studio > View > Command Bar, press Enter.",
    "local function make(className, name, parent, source)",
    "\tlocal old = parent:FindFirstChild(name)",
    "\tif old then old:Destroy() end",
    "\tlocal s = Instance.new(className)",
    "\ts.Name = name",
    "\ts.Source = source",
    "\ts.Parent = parent",
    "end",
]
for cls, name, parent, path in FILES:
    src = (ROOT / path).read_text()
    assert f"]{EQ}]" not in src
    out.append(f'make("{cls}", "{name}", {parent}, [{EQ}[\n{src}]{EQ}])')
out.append('print("Zombie Waves installed! Press Play (F5) to test.")')
(ROOT / "Install.lua").write_text("\n".join(out) + "\n")
print("wrote Install.lua")
