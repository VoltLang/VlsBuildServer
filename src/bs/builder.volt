/*!
 * Perform the actual building of projects by calling Battery.  
 * These functions should not be called by the main thread.
 */
module bs.builder;

import io = watt.io;
import toolchain = bs.toolchain;

fn test() i32
{
	batpath := toolchain.getBinary("battery");
	io.writeln(batpath);
	return 0;
}

fn build(projectRoot: string)
{
}

private:

