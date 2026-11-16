-- Autostart apps/daemons
hl.on("hyprland.start", function()
	hl.exec_cmd("waybar")
	hl.exec_cmd("blueman-applet")
	hl.exec_cmd("nm-applet")
	hl.exec_cmd("dunst")
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("nextcloud --background")
end)

-- Environment variables
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")

-- XWayland / Java
hl.env("OGL_DEDICATED_HW_STATE_PER_CONTEXT", "ENABLE_ROBUST")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XDG_STATE_HOME", os.getenv("HOME") .. "/.local/state")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
hl.env("LIBVIRT_DEFAULT_URI", "qemu:///system")

-- Auth
-- Fedora's ssh-agent.socket starts the shared agent on demand.
hl.env("SSH_AUTH_SOCK", os.getenv("XDG_RUNTIME_DIR") .. "/ssh-agent.socket")
