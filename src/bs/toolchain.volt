/*!
 * Prepare a Volt toolchain by harnessing the power of the INTERNET.  
 * These functions should not be called by the main thread.
 */
module bs.toolchain;

import io      = watt.io;
import semver  = watt.text.semver;
import file    = watt.io.file;
import text    = [watt.text.path, watt.text.string];
import path    = watt.path;

import github  = bs.github;
import net     = bs.net;
import extract = bs.extract;

/*!
 * Ensure that we have a functioning toolchain.
 *
 * This will check the VLS extension folder for a toolchain,
 * and if it is not present, download it.
 *
 * @Returns `true` if the toolchain is present or we could retrieve it.
 * Or `false` if it isn't present, and we couldn't retrieve it.
 */
fn prepare() bool
{
	versions := findToolchains();
	if (versions.length == 0) {
		tczip: github.ReleaseFile;
		if (!getToolchainReleaseFile(out tczip)) {
			return false;
		}
		targetPath := text.concatenatePath(ToolchainDir, tczip.filename);
		if (!net.download(tczip.url, targetPath, tczip.size)) {
			return false;
		}
		versionString := getVersionFromToolchainArchiveFilename(targetPath);
		if (versionString is null) {
			return false;
		}
		extractPath := text.concatenatePath(ToolchainDir, versionString);
		path.mkdirP(extractPath);
		extract.archive(filename:targetPath, destination:extractPath);
		file.remove(targetPath);
	}
	return true;
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

fn getVersionFromToolchainArchiveFilename(filename: string) string
{
	idx := text.indexOf(filename, "toolchain-");
	if (idx <= 0) {
		return null;
	}
	filename = filename[cast(size_t)idx+"toolchain-".length .. $];
	end := getReleaseFileEnd();
	idx  = text.indexOf(filename, end);
	if (idx <= 0) {
		return null;
	}
	filename = filename[0 .. cast(size_t)idx-1];
	if (!semver.Release.isValid(filename)) {
		return null;
	}
	return filename;
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

fn getReleaseFileEnd() string
{
	version (Windows) return "x86_64-msvc.zip";
	else static assert(false, "implement bs.toolchain.getReleaseFileEnd");
}

fn getToolchainReleaseFile(out releaseFile: github.ReleaseFile) bool
{
	version (Windows) return github.getReleaseFile("bhelyer", "Toolchain", getReleaseFileEnd(), out releaseFile);
	else static assert(false, "implement bs.toolchain.getToolchainReleaseFile");
}
