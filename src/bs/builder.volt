/*!
 * Perform the actual building of projects by calling Battery.  
 * These functions should not be called by the main thread.
 */
module bs.builder;

private:

global gBuildPath: string;  //!< The folder of the project we're currently building.
