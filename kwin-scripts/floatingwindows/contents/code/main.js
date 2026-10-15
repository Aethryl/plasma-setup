const GAP = readConfig("gap", 6);
const EXCLUDE = String(readConfig("exclude", "app.zen_browser.zen,zen"))
    .split(",").map(name => name.trim().toLowerCase()).filter(Boolean);

function near(a, b) {
    return Math.abs(a - b) <= 1;
}

function fillsArea(geometry, area) {
    return near(geometry.x, area.x) && near(geometry.y, area.y)
        && near(geometry.width, area.width) && near(geometry.height, area.height);
}

function excluded(window) {
    return [window.resourceClass, window.resourceName, window.desktopFileName]
        .some(name => EXCLUDE.includes(String(name || "").toLowerCase()));
}

function insetArea(area) {
    return {
        x: area.x + GAP,
        y: area.y + GAP,
        width: area.width - 2 * GAP,
        height: area.height - 2 * GAP,
    };
}

function inset(window) {
    if (!window.normalWindow || window.fullScreen || !window.resizeable || window.move || window.resize)
        return;
    const area = workspace.clientArea(KWin.MaximizeArea, window);
    if (excluded(window)) {
        if (fillsArea(window.frameGeometry, insetArea(area)))
            window.frameGeometry = { x: area.x, y: area.y, width: area.width, height: area.height };
        return;
    }
    if (fillsArea(window.frameGeometry, area))
        window.frameGeometry = insetArea(area);
}

function track(window) {
    window.frameGeometryChanged.connect(() => inset(window));
    window.maximizedChanged.connect(() => inset(window));
    inset(window);
}

workspace.windowList().forEach(track);
workspace.windowAdded.connect(track);
