# Filesystem

Yellowleaf is build around a virtual file-system object.
This objects is used to get and create files or directories.
When getting a file or directory it returns another object that
is used to read/alter that file or directory.

# Drive
The base class, above described as file-system object,
but I just prefer saying 'Drive'.

- **`.path(paths...)` `.dir(path)`:**
  These two will be removed soon and can, for now, just
  be copied from the default drive.
- **`.stat(paths...)`:**
  Returns a File or Directory object belonging to that path.
- **`.create(paths...)`:**
  Returns a writable stream that you can.. write to.
- **`.createDir(paths...)`:**
  Just creates an empty directory..


# File/Directory
Methods/properties they both need.

**Properties:**
- **`@isDirectory`:**
  Whether or not it is an directory, pretty clear :p
- **`@size`:**
  Size of the file in xxx. <!-- TODO: In what? -->
- **`@stat`**
  Addition, optional, options that the reciever of the object may use,
  but also may not use. Things like edit times and inode stuff can be here.
- **`@relpath`**
  Path relative to the Drive root.
  Also the path this file has been, most likely, taken from.
- **`@name`:**
  Just the last part of the path: Filename with extension.
- **`@fullpath` - optional**:
  The total path on the drive that returned this.
  May or may not include a protocol, what you like.
- **`@drive` - optional:**
  The drive that summoned this entity.
  Not required but very handy.

## `.rename(to)`
Move the file to the given path/name.
It works, like all methods,
with both relative (to the current cwd, I guess)
and absolute (to the Drive root) path.

## `.remove()`
Just removes the file, haha :-)

## `.info()`
Returns some info in an object,
but I have no real requirements yet.. Hmm


# File
## `.read()`
Return a readable stream for the resource.

## `.write()`
Open a writable stream to the resource.

## `.modify(TransformStream)`
'In place' modification of the file:
Pipes the resource through the TransformStream and
save the result.


# Directory
## `.list()`
Return a array of Entities in the current directory.

## `.listDeep()`
Utility using `.list()` that will return all entities
in nested folders. Should soon be inherited some way.
