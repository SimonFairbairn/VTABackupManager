VTABackupManager
================

Quick and easy way to archive <del>and read</del> Core Data managed object graphs.

Grabs the persistentStoreCoordinator of the passed context, then creates a private queue from that coordinator and runs on a background thread. Takes a completion block that will tell you if it was successful or not and, if not, give you a hint as to what went wrong.

Will also clean up backups older than 14 days (optional, set to 0 if you never want it to delete old backups).

**NOTE: You can only currently backup. Working on restore.**

1. Add classes to your project
1. Import the `VTABackupManager.h` file
1. Init with: `-(VTABackupManager *)initWithManagedObjectContext:(NSManagedObjectContext *)context entityToBackup:(NSEntityDescription *)entity;`, passing in your managed object context and the entity description of the entity you're interested in.
1. Run with `-(void)backupWithCompletionHandler:(void (^)(BOOL success, NSError *error))completion forceOverwrite:(BOOL)overwrite;`, passing on a completition handler to clean up, warn users, do whatever.


