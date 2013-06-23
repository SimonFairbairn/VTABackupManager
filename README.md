VTABackupManager
================

Quick and easy way to archive <del>and read</del> Core Data managed object graphs.

**NOTE: You can only currently backup. Working on restore.**

1. Add classes to your project
1. Import the `VTABackupManager.h` file
1. Init with 

    -(VTABackupManager *)initWithManagedObjectContext:(NSManagedObjectContext *)context entityToBackup:(NSEntityDescription *)entity;
    
1. 
