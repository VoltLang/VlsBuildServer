/*!
 * Create a file that has two properties:
 * - Only one process can have it open at once.
 * - When the process is closed, no matter how, the file will be deleted.
 * This is useful for ensuring multiple instances of the same bs don't
 * trash the toolchain folder with simultaneous access.
 */
module bs.lockFile.lockFileWindows;
version (Windows):

import win32 = core.c.windows;
import watt  = [watt.conv, watt.text.utf, watt.io];

//! Represents a single lock file.
alias Handle = void*;

/*!
 * Open a lock file with the given path.
 * 
 * @Returns `null` if the lock couldn't be opened, otherwise the
 * handle to the newly created lock file.
 */
fn get(path: string) Handle
{
	lpFilename := watt.toStringz(path);//watt.convertUtf8ToUtf16(path));
	hFile      := win32.CreateFileA(
		lpFilename, 0, 0, null,
		win32.CREATE_NEW,
		win32.FILE_ATTRIBUTE_NORMAL | win32.FILE_FLAG_DELETE_ON_CLOSE,
		null);
	if (cast(size_t)hFile == cast(size_t)win32.INVALID_HANDLE_VALUE) {
		return null;
	}
	err := win32.GetLastError();
	return cast(void*)hFile;
}

/*!
 * Release (delete) the given lock file.
 */
fn release(handle: Handle)
{
	if (handle is null) {
		return;
	}
	win32.CloseHandle(handle);
}
