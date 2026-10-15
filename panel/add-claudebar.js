var panel = panels().filter(function (p) { return p.location === "top"; })[0];
var spacer = panel.addWidget("org.kde.plasma.panelspacer");
spacer.currentConfigGroup = ["General"];
spacer.writeConfig("expanding", true);
panel.addWidget("io.github.aethryl.claudebar");
