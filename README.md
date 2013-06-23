VTABackupManager
================

Quick and easy way to archive and read Core Data managed object graphs.

Grabs the persistentStoreCoordinator of the passed context, then creates a private queue from that coordinator and runs on a background thread. Takes a completion block that will tell you if it was successful or not and, if not, give you a hint as to what went wrong.

Will also clean up backups older than 14 days (optional, set to 0 if you never want it to delete old backups).

### Backup

1. Add classes to your project
1. Import the `VTABackupManager.h` file
1. Init with: 
`-[[VTABackupManager alloc] initWithManagedObjectContext:(NSManagedObjectContext *)context
                                    entityToBackup:(NSEntityDescription *)entity];`
passing in your managed object context and the entity description of the entity you're interested in.
1. Run with: 
`-[VTABackupManager backupWithCompletionHandler:(void (^)(BOOL success, NSError *error))completion 
                     forceOverwrite:(BOOL)overwrite];`
passing on a completition handler to clean up, warn users, do whatever.

This will create a backup-<year>-<month>-<day>.vtabackup file in your user's documents/backup directory. You can specify a different URL if you want, and a different prefix if you prefer.

The `-[VTABackupManager listBackups];` method will return a list of all of the backup files found in the given directory.

### Restore

**WARNING: You have to manage your own persistent store before restoring. If you want it to restore the backup to an empty store, it's up to you to set up your persistent store as a blank slate. Otherwise, this utility will simply append everything in the backup to whatever context you give, resulting in possible duplicates.**

The reason for this is you may have an initial non-empty state for your database that you need to create first (e.g. a table full of initial categories or tags). This utility has no idea what the pristine state of your persistent store should look like, and will therefore assume nothing about it. 

<del>When it comes to relationships, it will look for an existing entry that matches the relationship entity first and, if it finds it, will link to that and not create a new object for that relationship (to prevent duplicate relationship objects).

Otherwise, it will create a new object to fulfill the relationship.</del>

Relationship support coming soon.

1. Set up your persistent store how you want it.
1. Initialise a backup manager instance with:
`-[[VTABackupManager alloc] initWithManagedObjectContext:(NSManagedObjectContext *)context
                                    entityToBackup:(NSEntityDescription *)entity];`
1. Run
`-(void)restoreFromURL:(NSURL *)URL withCompletitionHandler:(void (^)(BOOL success, NSError *error))completion;`
passing in a valid URL for a location for your backups (which you can obtain from `-[VTABackupManager listBackups]`