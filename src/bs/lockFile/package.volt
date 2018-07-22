module bs.lockFile;

version (Windows) {
	public import bs.lockFile.lockFileWindows;
} else {
	public import bs.lockFile.lockFileFallback;
}

