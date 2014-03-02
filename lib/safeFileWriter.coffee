fs = require("fs")
pathModule = require("path")
class SafeFileWriter
    @uninitialized = "uninitialized"
    @saved = "saved"
    @caching = "caching"
    @saving = "saving"
    constructor:(@path)->
        if not @path
            throw new Error "SafeFileWriter need a path"
        @state = SafeFileWriter.uninitialized
        @content = null
        @_savingBuffer = null
        @_waitBuffer = null
    save:(content,callback = ()->true)->
        if @_waitBuffer and @_waitBufferCallback
            # ignore the last saving
            @_waitBufferCallback "overwrite"
        @_waitBuffer = content
        @_waitBufferCallback = callback
        process.nextTick @_next.bind(this)
    _next:()->
        # nothing to save
        if not @_waitBuffer
            return
        # another saving is undergoing
        if @state is SafeFileWriter.saving
            return
        toSave = @_waitBuffer
        callback = @_waitBufferCallback
        @_waitBuffer = null
        @_waitBufferCallback = null
        @_save toSave,(err)=>
            callback err
            @_next()
    _save:(toSave,callback)->
        @_savingBuffer = toSave
        _callback = callback
        callback = (err,result)=>
            @_savingBuffer = null
            _callback err,result
            @_next()
        fs.exists @path,(exists)=>
            if exists
                @_renameAndSave(toSave,callback)
            else
                @_directSave(toSave,callback)
    _directSave:(toSave,callback)->
        fs.writeFile @_getDumpFilePath(),"",(err)=>
            if err
                callback err
                return
            fs.writeFile @path,toSave,(err)=>
                if err
                    callback err
                    return
                fs.unlink @_getDumpFilePath(),(err)=>
                    if err
                        callback err
                        return
                    callback null,toSave
        
    _renameAndSave:(toSave,callback)->
        fs.rename @path,@_getDumpFilePath(),(err)=>
            if err
                callback err
                return
            fs.writeFile @path,toSave,(err)=>
                if err
                    callback err
                    return
                fs.unlink @_getDumpFilePath(),(err)=>
                    if err
                        callback err
                        return
                    callback null,toSave
        
    _getDumpFilePath:()->
        if @_dumpFilePath
            return @_dumpFilePath
        dumpName = "##"+pathModule.basename(@path)+".old"
        dumpPath = pathModule.join(pathModule.dirname(@path),dumpName)
        @_dumpFilePath = dumpPath
        return dumpPath
    restore:(callback)->
        fs.exists @_getDumpFilePath(),(exists)=>
            if exists
                @_recoverFromDumpFile callback
            else
                @_recoverFromOriginalFile callback
    _setContent:(content)->
        @_content = content
        @state = SafeFileWriter.caching
    _recoverFromOriginalFile:(callback)->
        fs.exists @path,(exists)=>
            if not exists
                @_setContent("")
                @state = SafeFileWriter.saved
                callback null,@_content
            else
                fs.readFile @path,(err,content)=>
                    if err
                        callback err
                        return
                    @_setContent(content)
                    @state = SafeFileWriter.saved
                    callback null,@_content
    _recoverFromDumpFile:(callback)->
        fs.rename @_getDumpFilePath(),@path,(err)=>
            if err
                callback err
                return
            fs.readFile @path,(err,content)=>
                @_setContent(content)
                @state = SafeFileWriter.saved
                callback null,@_content
module.exports = SafeFileWriter