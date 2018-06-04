/*!
 * Perform the actual building of projects by calling Battery.  
 * These functions should not be called by the main thread.
 */
module bs.builder;

import process = watt.process.pipe;
import io = watt.io;
import text = watt.text.string;
import path = [watt.path, watt.text.path];
import conv = watt.conv;

import lsp = vls.lsp;

import toolchain = bs.toolchain;

fn test() i32
{
	build(`D:\F\Code\volt64\Test`);
	return 0;
}

fn build(projectRoot: string) bool
{
	if (!doConfig(projectRoot)) {
		return false;
	}
	return doBuild(projectRoot);
}

private:

fn doConfig(projectRoot: string) bool
{
	batteryPath := toolchain.getBinary("battery");
	if (batteryPath is null) {
		return false;
	}

	nasmPath := toolchain.getBinary("nasm");
	if (nasmPath is null) {
		return false;
	}

	clangPath := toolchain.getBinary("clang");
	if (clangPath is null) {
		return false;
	}

	voltaPath := toolchain.getBinary("volta");
	if (voltaPath is null) {
		return false;
	}

	rtPath := toolchain.getRtSource();
	if (rtPath is null) {
		return false;
	}

	wattPath := toolchain.getWattSource();
	if (wattPath is null) {
		return false;
	}

	args: string[12];
	args[0 ] = "config";
	args[1 ] = "--chdir";
	args[2 ] = projectRoot;
	args[3 ] = "--cmd-volta";
	args[4 ] = voltaPath;
	args[5 ] = "--cmd-nasm";
	args[6 ] = nasmPath;
	args[7 ] = "--cmd-clang";
	args[8 ] = clangPath;
	args[9 ] = rtPath;
	args[10] = wattPath;
	args[11] = ".";

	retval: u32;
	output := process.getOutput(batteryPath, args[..], ref retval);

	if (retval != 0) {
		return false;
	}

	return true;
}

fn doBuild(projectRoot: string) bool
{
	batteryPath := toolchain.getBinary("battery");
	if (batteryPath is null) {
		return false;
	}

	args: string[3];
	args[0] = "--chdir";
	args[1] = projectRoot;
	args[2] = "build";

	retval: u32;
	output := process.getOutput(batteryPath, args[..], ref retval);

	if (retval != 0) {
		sendFirstError(projectRoot, output);
		return false;
	}

	return true;
}

//! Send the first volta error that occurs in `output` (if any).
fn sendFirstError(projectRoot: string, buildOutput: string)
{
	lines := text.splitLines(buildOutput);
	foreach (line; lines) {
		errorIndex := text.indexOf(line, "error");
		if (errorIndex < 0) {
			continue;
		}
		locationSlice := text.strip(line[0 .. errorIndex]);
		locationComponents := text.split(locationSlice, ':');
		if (locationComponents.length < 3) {
			continue;
		}
		filename := path.fullPath(path.concatenatePath(projectRoot, locationComponents[0]));
		uri      := lsp.getUriFromPath(filename);
		lineNum  := conv.toInt(locationComponents[1]);
		colNum   := conv.toInt(locationComponents[2]);
		msg      := text.strip(line[cast(size_t)errorIndex + "error".length .. $]);
		if (text.startsWith(msg, ": ")) {
			msg = msg[2 .. $];
		}
		if (text.endsWith(msg, ".")) {
			msg = msg[0 .. $-1];
		}
		lsp.send(lsp.buildDiagnostic(uri, lineNum-1, colNum, lsp.DiagnosticLevel.Error, msg, projectRoot));
		return;
	}
}
