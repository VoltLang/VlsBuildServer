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
	batpath := toolchain.getBinary("battery");
	if (batpath is null) {
		return false;
	}
	config(projectRoot, batpath);
	return true;
}

private:

fn config(projectRoot: string, batteryPath: string) bool
{
	wattPath := toolchain.getWattSource();
	if (wattPath is null) {
		return false;
	}

	args: string[5];
	args[0] = "config";
	args[1] = "--chdir";
	args[2] = projectRoot;
	args[3] = wattPath;
	args[4] = ".";

	io.writeln(new "${batteryPath} ${args[0 .. $]}");
	output := process.getOutput(batteryPath, args[0 .. $]);
	io.writeln(output);

	return true;
}
