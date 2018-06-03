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
	io.writeln(new "build(${projectRoot})");
	config(projectRoot);
	return true;
}

private:

fn config(projectRoot: string) bool
{
	batteryPath := toolchain.getBinary("battery");
	if (batteryPath is null) {
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

	args: string[8];
	args[0] = "config";
	args[1] = "--chdir";
	args[2] = projectRoot;
	args[3] = "--cmd-volta";
	args[4] = voltaPath;
	args[5] = rtPath;
	args[6] = wattPath;
	args[7] = ".";

	io.writeln(new "${batteryPath} ${args[0 .. $]}");
	output := process.getOutput(batteryPath, args[0 .. $]);
	io.writeln(output);

	return true;
}
