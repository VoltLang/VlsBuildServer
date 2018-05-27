module main;

import watt = [watt.io, watt.io.streams, watt.io.seed, watt.math.random, watt.process.spawn,
	watt.text.path, watt.io.file, watt.path];
import json = watt.json;
import lsp = vls.lsp;
static import build;

private global buildManager: build.Manager;
private global pendingBuild: build.Build;

fn main(args: string[]) i32
{
	buildManager = new build.Manager(watt.getExecDir());

	fn handle(msg: lsp.LspMessage) bool
	{
		ro := new lsp.RequestObject(msg.content);
		// check content
		buildProject(ro);
		return true;
	}

	while (lsp.listen(handle, watt.input)) {
	}

	return 0;
}

fn buildProject(ro: lsp.RequestObject)
{
	arguments := lsp.getArrayKey(ro.params, "arguments");
	if (arguments.length == 0) {
		return;
	}
	if (arguments[0].type() != json.DomType.Object) {
		return;
	}
	fspath := lsp.getStringKey(arguments[0], "fsPath");
	btoml := lsp.getBatteryToml(fspath);
	if (btoml is null) {
		return;
	}
	pendingBuild = buildManager.spawnBuild(btoml);
}
