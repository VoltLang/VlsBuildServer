/*!
 * Perform the actual building of projects by calling Battery.  
 * These functions should not be called by the main thread.
 */
module bs.builder;

import win32 = core.c.windows;
import process = watt.process.pipe;
import io = watt.io;
import text = [watt.text.ascii, watt.text.string, watt.text.utf];
import file = watt.io.file;
import path = [watt.path, watt.text.path];
import conv = watt.conv;

import lsp = vls.lsp;

import toolchain = bs.toolchain;

fn build(projectRoot: string) bool
{
	toolchain.getLock();
	scope (exit) toolchain.releaseLock();
	if (!alreadyConfigured(projectRoot)) {
		if (!doConfig(projectRoot)) {
			return false;
		}
	}
	return doBuild(projectRoot);
}

private:

fn alreadyConfigured(projectRoot: string) bool
{
	p := path.concatenatePath(projectRoot, ".battery/config.txt");
	return file.exists(p);
}

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

fn splitLocation(str: string, ref filename: string, ref line: i32, ref column: i32) bool
{
	if (str.length <= 1) {
		return false;
	}
	if (str[$-1] == ':') {
		str = str[0 .. $-1];
	}
	i := str.length;
	fileIndex, lineIndex, columnIndex: ptrdiff_t;
	fileIndex = lineIndex = columnIndex = -1;
	while (i > 0) {
		c := str[--i];
		if (columnIndex == -1) {
			if (c == ':') {
				columnIndex = cast(ptrdiff_t)(i);
				column = conv.toInt(text.strip(str[i+1 .. $]));
			} else if (!text.isDigit(c)) {
				return false;
			}
		} else if (lineIndex == -1) {
			if (c == ':') {
				lineIndex = cast(ptrdiff_t)(i);
				line = conv.toInt(text.strip(str[i+1 .. columnIndex]));
			} else if (!text.isDigit(c)) {
				return false;
			}
		}
	}
	if (columnIndex != -1 && lineIndex != -1) {
		filename = text.strip(str[0 .. lineIndex]);
		return true;
	}
	return false;
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
		filename: string;
		lineNum, colNum: i32;
		if (!splitLocation(locationSlice, ref filename, ref lineNum, ref colNum)) {
			continue;
		}
		if (!isAbsolutePath(filename)) {
			filename = path.concatenatePath(projectRoot, filename);
		}
		uri      := lsp.getUriFromPath(filename);
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

fn isAbsolutePath(thePath: string) bool
{
	version (!Windows) {
		return thePath.length > 0 && thePath[0] == '/';
	} else {
		widePath := text.convertUtf8ToUtf16(thePath);
		wideStr  := conv.toStringz(widePath);
		return win32.PathIsRelativeW(wideStr) == win32.FALSE;
	}
}
