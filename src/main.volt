module main;

import watt = [watt.io, watt.io.streams, watt.io.seed, watt.math.random, watt.process.spawn,
	watt.text.path, watt.io.file, watt.path];
import json = watt.json;
import lsp = vls.lsp;
static import build;

global gLog: watt.OutputFileStream;
private global buildManager: build.Manager;
private global pendingBuild: build.Build;

fn main(args: string[]) i32
{
	buildManager = new build.Manager(watt.getExecDir());
	openLog();
	scope (exit) gLog.close();

	fn handle(msg: lsp.LspMessage) bool
	{
		gLog.writeln(msg.content);
		gLog.writeln("");
		gLog.flush();
		ro := new lsp.RequestObject(msg.content);
		// check content
		buildProject(ro);
		return true;
	}

	while (lsp.listen(handle, watt.input)) {
	}

	return 0;
}

fn openLog()
{
	rng: watt.RandomGenerator;
	rng.seed(watt.getHardwareSeedU32());
	inputPath := watt.getEnv("USERPROFILE") ~ "/Desktop/vlsInLog." ~ rng.randomString(4) ~ ".txt";
	gLog = new watt.OutputFileStream(inputPath);
}

// move
fn buildProject(ro: lsp.RequestObject)
{
	arguments := getArrayKey(ro.params, "arguments");
	if (arguments.length == 0) {
		return;
	}
	if (arguments[0].type() != json.DomType.Object) {
		return;
	}
	fspath := getStringKey(arguments[0], "fsPath");
	btoml := getBatteryToml(fspath);
	if (btoml is null) {
		return;
	}
	pendingBuild = buildManager.spawnBuild(btoml);
}

// duplicate
fn validateKey(root: json.Value, field: string, t: json.DomType, ref val: json.Value) bool
{
	if (root.type() != json.DomType.Object ||
		!root.hasObjectKey(field)) {
		return false;
	}
	val = root.lookupObjectKey(field);
	if (val.type() != t) {
		return false;
	}
	return true;
}

// duplicate
fn getStringKey(root: json.Value, field: string) string
{
	val: json.Value;
	retval := validateKey(root, field, json.DomType.String, ref val);
	if (!retval) {
		return null;
	}
	return val.str();
}

// duplicate
fn getArrayKey(root: json.Value, field: string) json.Value[]
{
	val: json.Value;
	retval := validateKey(root, field, json.DomType.Array, ref val);
	if (!retval) {
		return null;
	}
	return val.array();
}

// duplicate (move?)
fn getBatteryToml(path: string) string
{
	basePath := path;
	while (basePath.length > 0) {
		srcDir := watt.concatenatePath(basePath, "src");
		if (watt.isDir(srcDir)) {
			btoml := watt.concatenatePath(basePath, "battery.toml");
			if (watt.exists(btoml)) {
				return btoml;
			} else {
				return null;
			}
		}
		parentDirectory(ref basePath);
	}
	return null;
}

// duplicate
fn parentDirectory(ref path: string)
{
	while (path.length > 0 && path[$-1] != '/' && path[$-1] != '\\') {
		path = path[0 .. $-1];
	}
	if (path.length > 0) {
		path = path[0 .. $-1];  // Trailing slash.
	}
}
