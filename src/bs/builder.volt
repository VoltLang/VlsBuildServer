/*!
 * Perform the actual building of projects by calling Battery.  
 * These functions should not be called by the main thread.
 */
module bs.builder;

import process = watt.process.pipe;
import io = watt.io;
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
	doBuild(projectRoot);
	return true;
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

	output := process.getOutput(batteryPath, args[..]);

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

	output := process.getOutput(batteryPath, args[..]);

	return true;
}
