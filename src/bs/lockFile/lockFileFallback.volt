module bs.lockFile.lockFileFallback;

/* This doesn't really need to be fancy,
 * just functional.
 */

import file = watt.io.file;

//! Represents a single lock file.
alias Handle = void*;

struct FilePath
{
	fpath: string;
}

/*!
 * Open a lock file with the given path.
 * 
 * @Returns `null` if the lock couldn't be opened, otherwise the
 * handle to the newly created lock file.
 */
fn get(path: string) Handle
{
	if (file.exists(path)) {
		return null;
	}
	file.write("hello", path);
	fp := new FilePath;
	fp.fpath = path;
	return cast(Handle)fp;
}

/*!
 * Release (delete) the given lock file.
 */
fn release(handle: Handle)
{
	fp := cast(FilePath*)handle;
	if (fp is null || !file.exists(fp.fpath)) {
		return;
	}
	file.unlink(fp.fpath);
}
