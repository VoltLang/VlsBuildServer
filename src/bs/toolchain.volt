/*!
 * Prepare a Volt toolchain by harnessing the power of the INTERNET.  
 * These functions should not be called by the main thread.
 */
module bs.toolchain;

import io = watt.io;
import semver = watt.text.semver;
import file = watt.io.file;
import text = watt.text.path;
import path = watt.path;

import github = bs.github;
import net = bs.net;

//! Signify the status of the toolchain.
alias Status = i32;
enum : Status
{
	Ok,               //!< The toolchain is present.
	DownloadFailure,  //!< We tried to download the toolchain, but failed.
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
	versions := findToolchains();
	if (versions.length == 0) {
		tczip: github.ReleaseFile;
		if (!getToolchainReleaseFile(out tczip)) {
			return DownloadFailure;
		}
		targetpath := text.concatenatePath(ToolchainDir, tczip.filename);
		if (!net.download(tczip.url, targetpath, tczip.size)) {
			return DownloadFailure;
		}
	}
	return Ok;
}

fn test() i32
{
	prepare();   // prepare, prepare, prepare
	return 0;
}

private:

struct Toolchain
{
	release: semver.Release;
	path:    string;
}

enum ToolchainDir    = "toolchain";  // (In the VLS extension folder)

fn createToolchainDirectory()
{
	if (file.isDir(ToolchainDir)) {
		return;
	}
	path.mkdirP(ToolchainDir);
}

/*!
 * Find all installed toolchains.
 */
fn findToolchains() Toolchain[]
{
	path := ToolchainDir;

	versions: Toolchain[];

	fn checkDirectory(s: string) file.SearchStatus
	{
		if (!semver.Release.isValid(s)) {
			return file.SearchStatus.Continue;
		}
		target := text.concatenatePath(path, s);
		if (!validToolchain(target)) {
			return file.SearchStatus.Continue;
		}
		tc: Toolchain;
		tc.release = new semver.Release(s);
		tc.path = target;
		versions ~= tc;
		return file.SearchStatus.Continue;
	}

	createToolchainDirectory();
	file.searchDir(path, "*", checkDirectory);

	return versions;
}

//! @Returns `true` if `dir` looks vaguely like a toolchain to us. Not very thorough.
fn validToolchain(dir: string) bool
{
	version (Windows) {
		target := "bin/battery.exe";
	} else {
		target := "bin/battery";
	}
	dir = text.concatenatePath(dir, target);
	return file.exists(dir);
}

fn getToolchainReleaseFile(out releaseFile: github.ReleaseFile) bool
{
	version (Windows) return github.getReleaseFile("bhelyer", "Toolchain", "x86_64-msvc.zip", out releaseFile);
	else static assert(false, "implement bs.toolchain.getToolchainReleaseFile");
}
