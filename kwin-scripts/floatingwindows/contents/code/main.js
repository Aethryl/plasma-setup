const GAP = readConfig("gap", 6);
const EXCLUDE = String(readConfig("exclude", ""))
    .split(",").map(name => name.trim().toLowerCase()).filter(Boolean);

function near(a, b) {
    return Math.abs(a - b) <= 2;
}

const SPANS = [[0, 1], [0, 0.5], [0.5, 1]];

function tileRect(area, xs, ys) {
    const x0 = area.x + Math.round(area.width * xs[0]);
    const x1 = area.x + Math.round(area.width * xs[1]);
    const y0 = area.y + Math.round(area.height * ys[0]);
    const y1 = area.y + Math.round(area.height * ys[1]);
    return { x: x0, y: y0, width: x1 - x0, height: y1 - y0 };
}

function quickTile(geometry, area) {
    for (const xs of SPANS)
        for (const ys of SPANS) {
            if (xs[1] - xs[0] === 1 && ys[1] - ys[0] === 1)
                continue;
            if (fillsArea(geometry, tileRect(area, xs, ys)))
                return tileRect(area, xs, ys);
        }
    return null;
}

function insetTile(rect, area) {
    const half = Math.round(GAP / 2);
    const left = near(rect.x, area.x) ? GAP : half;
    const top = near(rect.y, area.y) ? GAP : half;
    const right = near(rect.x + rect.width, area.x + area.width) ? GAP : half;
    const bottom = near(rect.y + rect.height, area.y + area.height) ? GAP : half;
    return {
        x: rect.x + left,
        y: rect.y + top,
        width: rect.width - left - right,
        height: rect.height - top - bottom,
    };
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
    if (fillsArea(window.frameGeometry, area)) {
        window.frameGeometry = insetArea(area);
        return;
    }
    const tile = quickTile(window.frameGeometry, area);
    if (tile)
        window.frameGeometry = insetTile(tile, area);
}

function track(window) {
    window.frameGeometryChanged.connect(() => inset(window));
    window.maximizedChanged.connect(() => inset(window));
    inset(window);
}

workspace.windowList().forEach(track);
workspace.windowAdded.connect(track);
