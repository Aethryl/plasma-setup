var panel = panels().filter(function (p) { return p.location === "top"; })[0];
if (panel.widgets("io.github.aethryl.mural").length === 0) {
    panel.addWidget("io.github.aethryl.mural");
}
