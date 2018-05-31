/*!
 * Prepare a Volt toolchain by harnessing the power of the INTERNET.  
 * These functions should not be called by the main thread.
 */
module bs.toolchain;

import io = watt.io;
import semver = watt.text.semver;
import file = watt.io.file;
import text = watt.text.path;

//! Signify the status of the toolchain.
alias Status = i32;
enum : Status
{
	Ok,               //!< The toolchain is present.
	DownloadFailure,  //!< We tried to download the toolchain, but failed.
}

//! The types of tool this module handles.
enum Type
{
	Battery,
	Volta,
}

/*!
 * Ensure that we have a functioning toolchain.
 *
 * This will check the VLS extension folder for a toolchain,
 * and if it is not present, download it.
 *
 * @Returns `Ok` if the toolchain is present.
 */
fn prepare() Status
{
	return Ok;
}

/*!
 * Get the latest version of the given tool that is installed.
 *
 * @Returns The path to the executable, or `null` if no installs are present.
 */
fn get(type: Type) string
{
	return null;
}

fn test() i32
{
	versions := findVersions(Type.Battery, BatteryDir, BatteryTarget);
	versions ~= findVersions(Type.Volta, VoltaDir, VoltaTarget);
	if (versions.length == 0) {
		io.writeln("No batteries detected.");
		return 1;
	} else {
		foreach (ver; versions) {
			io.writeln(ver.toString());
		}
	}
	return 0;
}

private:

//! An individual install of a tool.
struct ToolInstall
{
	type: Type;               //!< The kind of tool this install represents.
	release: semver.Release;  //!< The version of this install.
	executablePath: string;   //!< The path to the tool executable.

	fn toString() string
	{
		return new "{${type} ${release} ${executablePath}}";
	}
}

/* ToolchainDir layout:
 * [~/.vscode/extensions]  (our CWD)
 * |
 * +--[toolchain]
 *    |
 *    +--[battery]
 *    |  |
 *    |  +--[0.1.16]
 *    |  |  |
 *    |  |  +--battery.exe
 *    |  |
 *    |  +--[0.2.12]
 *    |     |
 *    |     +--battery.exe
 *    +--[volta] (etc)
 */
enum ToolchainDir    = "toolchain";  // (In the VLS extension folder)
enum BatteryDir      = "${ToolchainDir}/battery";
enum BatteryTarget   = "battery";
enum VoltaDir        = "${ToolchainDir}/volta";
enum VoltaTarget     = "volta";

//! @Returns All present install versions (if any) for the given tool type.
fn toolVersions(type: Type) ToolInstall[]
{
	final switch (type) with (Type) {
	case Battery: return findVersions(type, BatteryDir, BatteryTarget);
	case Volta:   return findVersions(type, VoltaDir, VoltaTarget);
	}
}

/*!
 * Find all installed versions of a given type in a given path.
 *
 * The `type` field of the `ToolInstall` structures (if any) will
 * be initialised to `type`. The `release` will be the directory
 * name, and `executablePath` will be the full path to that `targetName`.
 * If the platform is Windows, this will look for `${targetName}.exe`.
 *
 * @Returns Every directory directly under `path` that is named a valid semver,
 * and has a file named `targetName` in it.
 */
fn findVersions(type: Type, path: string, targetName: string) ToolInstall[]
{
	version (Windows) {
		targetName = new "${targetName}.exe";
	}

	versions: ToolInstall[];

	fn checkDirectory(s: string) file.SearchStatus
	{
		if (!semver.Release.isValid(s)) {
			return file.SearchStatus.Continue;
		}
		target := text.concatenatePath(path, s);
		target  = text.concatenatePath(target, targetName);
		if (!file.exists(target)) {
			return file.SearchStatus.Continue;
		}
		ti: ToolInstall;
		ti.type = type;
		ti.release = new semver.Release(s);
		ti.executablePath = target;
		versions ~= ti;
		return file.SearchStatus.Continue;
	}

	file.searchDir(path, "*", checkDirectory);

	return versions;
}
