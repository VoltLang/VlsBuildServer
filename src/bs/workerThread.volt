/*!
 * The worker thread does thing like downloading tools and running
 * builds, so the main thread can respond to client requests in a
 * timely manner.
 */
module bs.workerThread;

import core = [core.exception, core.rt.thread];
import io = watt.io;
import path = watt.path;

import lsp = vls.lsp;

import builder = bs.builder;
import toolchain = bs.toolchain;

/*!
 * Informs the caller if a work request was received.
 */
alias Status = i32;
enum : Status
{
	Ok,    //!< Work will start/has started on the request.
	Fail,  //!< The work failed.
}

/*!
 * Start the worker thread.  
 * The thread runs until the build server process terminates.
 */
fn start()
{
	gThread = core.vrt_thread_start_fn(loop);
	if (core.vrt_thread_error(gThread)) {
		throw new core.Exception(core.vrt_thread_error_message(gThread));
	}
}

/*!
 * Stop the worker thread, release associated resources.
 */
fn stop()
{
	core.vrt_mutex_delete(gRootsMutex);
	changeTask(Task.Shutdown);
	if (gTask != Task.Shutdown) {
		io.error.writeln("Couldn't cleanly shutdown build server worker thread.");
		return;
	}
	core.vrt_thread_join(gThread);
	gThread = null;
}

/*!
 * Set a function for the worker thread to report a build completion to.
 */
fn setReportFunction(func: fn(Status, string))
{
	gReportFunction = func;
}

/*!
 * Add a build to the build queue.
 */
fn addBuild(projectRoot: string)
{
	core.vrt_mutex_lock(gRootsMutex);
	scope (exit) core.vrt_mutex_unlock(gRootsMutex);
	gProjectRoots ~= projectRoot;
}

private:

global this()
{
	gRootsMutex = core.vrt_mutex_new();
}

//! The states this thread can be in.
enum Task
{
	Sleep,    //!< Wait until asked to do something. Initial state.
	Build,    //!< There are one or more builds to be processed.
	Shutdown, //!< Stop working.
}

global gThread: core.vrt_thread*;            //!< Handle for the thread.
global gTask: Task;                          //!< What the thread has been asked to do.
global gProjectRoots: string[];              //!< What the thread has been asked to build.
global gRootsMutex: core.vrt_mutex*;         //!< Lock for write access to gProjectRoots.
global gReportFunction: fn(Status, string);  //!< Build status, project root.

/*!
 * Try to change the current task to `newTask`.  
 * The previous task may still be pending, so the task may not change.
 */
fn changeTask(newTask: Task)
{
	if (gTask == Task.Sleep) {
		gTask = newTask;
	}
}

//! Dispatch to the handler for the current task.
fn loop()
{
	shutdown := false;
	toolchainPrepared := false;
	while (!shutdown) {
		final switch (gTask) with (Task) {
		case Sleep:
			core.vrt_sleep(10);
			prepareToolchain(ref toolchainPrepared);
			if (!toolchainPrepared) {
				continue;
			}
			// Reading should be fine without the lock.
			if (gProjectRoots.length > 0) {
				gTask = Build;
				continue;
			}
			break;
		case Shutdown: shutdown = true; break;
		case Build:
			core.vrt_mutex_lock(gRootsMutex);
			assert(gProjectRoots.length > 0);
			root := gProjectRoots[0];
			gProjectRoots = gProjectRoots[1 .. $];
			core.vrt_mutex_unlock(gRootsMutex);

			retval := builder.build(root);
			gReportFunction(retval ? Ok : Fail, root);
			if (gProjectRoots.length == 0) {
				gTask = Task.Sleep;
			}
			break;
		}
	}
}

fn prepareToolchain(ref toolchainPrepared: bool)
{
	if (toolchainPrepared) {
		return;
	}

	tchain: toolchain.Toolchain;
	toolchainPrepared = toolchain.prepareLatest(out tchain);
	if (toolchainPrepared) {
		uri := lsp.getUriFromPath(path.fullPath(tchain.path));
		msg := lsp.buildVlsToolchainPresentNotification(uri);
		lsp.send(msg);
	} else {
		// @todo report error?
	}
}
