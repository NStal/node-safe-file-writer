SafeFileWriter = require("../")
fs = require "fs"
describe "basic test",()->
    it "read from none exists file should return success and return empty",(done)->
        writer = new SafeFileWriter("./test1.config.json")
        console.assert writer.state is "uninitialized"
        writer.restore (err,content)->
            console.assert not err
            console.assert content is ""
            console.assert not fs.existsSync(writer.path)
            done()
    it "read from exists file without old file should return content",(done)->
        writer = new SafeFileWriter("./test2.config.json")
        fs.writeFileSync("./test2.config.json","hello")
        console.assert writer.state is "uninitialized"
        writer.restore (err,content)->
            console.assert not err
            console.assert content.toString() is "hello"
            console.assert fs.existsSync(writer.path)
            console.assert not fs.existsSync(writer._getDumpFilePath())
            fs.unlinkSync("./test2.config.json")
            done()
    it "when old file exists and file not exists  we should recover from old file",(done)->
        writer = new SafeFileWriter("./test3.config.json")
        fs.writeFileSync(writer._getDumpFilePath(),"hello")
        console.assert writer.state is "uninitialized"
        console.assert fs.existsSync(writer._getDumpFilePath())
        writer.restore (err,content)->
            console.assert not err
            console.assert content.toString() is "hello" 
            console.assert fs.existsSync(writer.path)
            console.assert not fs.existsSync(writer._getDumpFilePath())
            fs.unlinkSync writer.path
            done()
    it "when old file exists and file also exists  we should recover from old file",(done)->
        writer = new SafeFileWriter("./test4.config.json")
        fs.writeFileSync writer.path,"broken"
        fs.writeFileSync writer._getDumpFilePath(),"old"
        console.assert writer.state is "uninitialized"
        writer.restore (err,content)->
            console.assert not err
            console.assert content.toString() is "old" 
            console.assert fs.existsSync(writer.path)
            console.assert not fs.existsSync(writer._getDumpFilePath())
            fs.unlinkSync writer.path
            done()
    it "save several times in the same blocked context should has only the last one actually saved",(done)->
        writer = new SafeFileWriter("./test5.config.json")
        writer.restore (err)->
            console.assert not err
            writer.save "content1",(err)->
                console.assert err is "overwrite"
            writer.save "content2",(err)->
                console.assert err is "overwrite"
            writer.save "content3",(err)->
                console.log err
                console.assert not err,"should save without error"
                console.assert fs.readFileSync(writer.path,"utf8") is "content3"
                done()