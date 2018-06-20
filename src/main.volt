module main;

import watt = [watt.io, watt.path];
import json = watt.json;
import lsp = vls.lsp;
import workerThread =bs.workerThread;
import builder = bs.builder;
import watt.text.getopt;

import toolchain = bs.toolchain;
import core = core.rt.thread;

fn main(args: string[]) i32
{
	bool takeLock;
	if (getopt(ref args, "take-lock", ref takeLock)) {
		toolchain.getLock();
		core.vrt_sleep(10000);
		toolchain.releaseLock();
		return 1;
	}
	workerThread.start();
	scope (exit) workerThread.stop();
	workerThread.setReportFunction(buildComplete);

	fn handle(msg: lsp.LspMessage) bool
	{
		ro := new lsp.RequestObject(msg.content);
		handleRequest(ro);
		return true;
	}

	while (lsp.listen(handle, watt.input)) {
	}

	return 0;
}

fn handleRequest(ro: lsp.RequestObject)
{
	if (ro.methodName != "workspace/executeCommand") {
		return;
	}
	command := lsp.getStringKey(ro.params, "command");
	switch (command) {
	case "vls.buildProject":
		buildProject(ro);
		break;
	case "vls.buildAllProjects":
		buildAllProjects(ro);
		break;
	default:
		watt.error.writeln(new "VlsBuildServer: Unknown Command '${command}'");
		break;
	}
}

fn buildComplete(status: workerThread.Status, buildPath: string)
{
	if (status == workerThread.Ok) {
		lsp.send(lsp.buildVlsBuildSuccessNotification(buildPath));
	} else if (status == workerThread.Fail) {
		lsp.send(lsp.buildVlsBuildFailureNotification(buildPath));
	}
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
	buildPath := watt.dirName(btoml);
	workerThread.addBuild(buildPath);
}

fn buildAllProjects(ro: lsp.RequestObject)
{
	arr := lsp.getArrayKey(ro.params, "workspaceUris");
	foreach (el; arr) {
		workerThread.addBuild(lsp.getPathFromUri(el.str()));
	}
}
