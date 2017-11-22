# Deprecated please use [SwiftActor](https://github.com/LawrenceHan/SwiftActor)

# ActionStageSwift
A Swift version of ActionStage.
Actor Model

## Getting Started

#### Watch something

ActionStage can watch a path (string), For example: `ActionStageInstance.watchForPath("/myapp/tableview/hasnewcell", watcher: self)`. You can also watch for a generic path: ActionStageInstance.watchForPath("/myapp/userdetail/@", @ is token. Any path start with `/myapp/userdetail` will trigger the delegate.

#### Dispatch resources

`ActionStageInstance.dispatchResource(path: "/myapp/userdetail/(97172)", resource: text, arguments: nil)`

#### Handle dispatched resouce

``` swift
func actorCompleted(status: LHWActionStageStatus, path: String, result: Any?)
func actorReportedProgress(path: String, progress: Float)
func actionStageResourceDispatched(path: String, resource: Any?, arguments: Any?)
func actionStageActionRequested(_ action: String, options: Dictionary<String, Any>?)
func actorMessageReceived(path: String, messageType: String?, message: Any?)
```

``` swift
func actionStageResourceDispatched(path: String, resource: Any?, arguments: Any?) {
    if path == "/myapp/userdetail/\(currentUserId)" {
        LHWDispatchOnMainThread {
            self.tableView.reloadData()
        }
    }
}
```

#### Create an Actor

``` swift
import Foundation

class AddCellActor: LHWActor {
    
    override class func genericPath() -> String? {
        return "/myapp/userdetail/@" // Actor path
    }
    
    override func execute(options: [String: Any]?) {
        guard let options = options else {
            return
        }
        
        guard let text = options["text"] as? String else { // in this case we passed a string parameter to it
            return
        }
        
        // Do something
        something()
        
        // Dispatch resource or notify any watcher 
        ActionStageInstance.dispatchResource(path: path, resource: text, arguments: nil)
        
        // Tell wather this actor is done its job.
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            ActionStageInstance.actionCompleted(self.path)
        }
    }
    
    override func watcherJoined(watcherHandler: LHWHandler, options: [String : Any]?, waitingInActorQueue: Bool) {
        Logger.debug("joined handler: \(watcherHandler), options: \(options ?? [:]), path: \(path)")
    }
}
```

#### Register an actor

```LHWActor.registerActorClass(AddCellActor.self)```

#### Call an actor

``` swift
func addCell() {
    let options = ["text": "new cell \(array.count+1)"]
    ActionStageInstance.requestActor(path: "/myapp/userdetail/(97172)", options: options, watcher: nil)
}
```

# Dotation: buy me a cup of coffee maybe?
This project is under **MIT** license, basiclly you can do whatever you want with it.

It won't hurt to buy me a cup of coffee, so I can spend more time on bringing more good stuffs to you guys.

Currently I can only work on open-source project in my personal time (evening/weekend/holiday).

# Paypal
https://www.paypal.me/LawrenceGuangHan/

# Alipay
https://github.com/LawrenceHan/ActionStageSwift/blob/master/payme.JPG
