const GAP = readConfig("gap", 6);

function near(a, b) {
    return Math.abs(a - b) <= 1;
}

function fillsArea(geometry, area) {
    return near(geometry.x, area.x) && near(geometry.y, area.y)
        && near(geometry.width, area.width) && near(geometry.height, area.height);
}

function inset(window) {
    if (!window.normalWindow || window.fullScreen || !window.resizeable || window.move || window.resize)
        return;
    const area = workspace.clientArea(KWin.MaximizeArea, window);
    if (!fillsArea(window.frameGeometry, area))
        return;
    window.frameGeometry = {
        x: area.x + GAP,
        y: area.y + GAP,
        width: area.width - 2 * GAP,
        height: area.height - 2 * GAP,
    };
}

function track(window) {
    window.frameGeometryChanged.connect(() => inset(window));
    window.maximizedChanged.connect(() => inset(window));
    inset(window);
}

workspace.windowList().forEach(track);
workspace.windowAdded.connect(track);
