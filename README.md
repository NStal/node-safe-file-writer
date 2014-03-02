# Why this package
Due to nodejs's async natural, when saving configs to filesystem, another uncaught exception will quit the program immediately and result in a broken config file. This module handle this problem.

# Usage
```coffee-script
SafeFileWriter = require("safe-file-writer")
writer = new SafeFileWriter("./config.json")
config = {
           key:"newValue"
}
newConfigString = JSON.stringify(config)

# you can access writer state via SafeFileWriter.state

# echo uninitialized
console.log writer.state

# restore from previous state if has any, or recover the broken file if any 
writer.restore (err,value)->
	# echo saved
	console.log writer.state 
               
        # save the config
	writer.save newConfigString,(err)->
            if err
               # echo caching
               console.log writer.state
               return

            # echo saved
            console.log writer.state
            # echo {"key":""value}
            # writer.content can be Buffer or String depends on what you save
            console.log writer.content
        # echo saving
	console.log writer.state

# Note1: only each file can only associated with 1 writer
#        or no good thing will happen.
# Note2: don't save before restore finished
```

# Behind the scene

Suppose we are going to save ```{"value":"newValue"}```to a file named "config.json" and there already exists a "config.json" with content ```{"value":"oldValue"}```.
Here is what happend:
s1. rename config.json to ##config.json.old 
s2. write {"value":"newValue"} to config.json
s3. unlink ##config.json.old 

Here is what happened when wo do the restore
r1. check if there is a ##config.json.old, any failure in s1~s3 will lead to this behavior.
   yes: let's unlink config.json if exists and rename ##config.json.old to config.json and restore from that file.
   no: goto r2
r2. check if there is an config.json
   yes: read file and result in a "saved" state
   no: result in a "saved" state

So any failure at s1,s2,s3 will result in a rollback to the last config state.


# Corner case bhavior
Continuously save several times at the same process tick (no setTimeout or process.nextTick between save) will ignore the action before last save and callback with a string "overwrite".
In this case physical disk will be only write once ().

```coffee-script
handler = (err)->console.err or "success"

writer.save "content1",handler
writer.save "content2",handler
writer.save "content3",handler

```

# States
* ```uninitialized ``` this is the state when the writer is created but has never been saved/set content/restored.
* ```saving``` We are writing files to filesystem as described in s1~s3, but not finished.
* ```saved``` Everything is safe, your file are already flush to the filesystem and no ## file are exists.
* ```cache``` writer are holding your content but not doing saving action. It's likely to be the result of the failure of the last save.


# Methods
```void save(content,callback)```
```content``` can be buffer or string, ```callback``` recieve an error if has any.


```void restore(callback)```
```callback(error,content)```, ```content``` can be buffer or string, ```callback``` recieve an error if has any.


