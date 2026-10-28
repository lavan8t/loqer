pragma Singleton
pragma ComponentBehavior: Bound

import "../modules/common"
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string filePath: {
        const xdgState = Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state");
        return xdgState + "/quickshell/user/generated/colors.json";
    }

    function reapplyTheme() {
        themeFileView.reload()
    }

    function applyColors(fileContent) {
        try {
            const json = JSON.parse(fileContent);
            for (const key in json) {
                if (json.hasOwnProperty(key)) {
                    const camelCaseKey = key.replace(/_([a-z])/g, (g) => g[1].toUpperCase());
                    const m3Key = `m3${camelCaseKey}`;
                    if (Appearance.m3colors.hasOwnProperty(m3Key)) {
                        Appearance.m3colors[m3Key] = json[key];
                    }
                }
            }
            Appearance.m3colors.darkmode = (Appearance.m3colors.m3background.hslLightness < 0.5);
        } catch (e) {
            // Keep default M3 dark theme
        }
    }

    FileView { 
        id: themeFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: {
            this.reload();
            if (themeFileView.text()) {
                root.applyColors(themeFileView.text());
            }
        }
        onLoadedChanged: {
            const fileContent = themeFileView.text();
            if (fileContent) {
                root.applyColors(fileContent);
            }
        }
    }
}
