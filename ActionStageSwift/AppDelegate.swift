//
//  AppDelegate.swift
//  ActionStageSwift
//
//  Created by Hanguang on 2017/3/7.
//  Copyright © 2017年 Hanguang. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        LHWActor.registerActorClass(AddCellActor.self)
        
//        let stageQueueSpecific = "com.hanguang.app.ActionStageSwift.StageDispatchQueue"
//        let stageQueueSpecificKey = DispatchSpecificKey<String>()
//        let mainStageQueue: DispatchQueue
//        let globalStageQueue: DispatchQueue
//        let highPriorityStageQueue: DispatchQueue
//        
//        
//        var str1: [String] = []
//        var str2: [String] = []
//        for i in 0..<30 {
//            str1.append("\(i)")
//        }
//        let item1: [String] = str1
//        
//        for i in 30..<60 {
//            str2.append("\(i)")
//        }
//        let item2: [String] = str2
//        
//        for text in item1 {
//            globalGraphQueue.async {
//                print(text)
//            }
//        }
//        
//        for text in item2 {
//            highPriorityGraphQueue.async {
//                print(text)
//            }
//        }
        
//        let house1Folks = ["Joe", "Jack", "Jill"];
//        let house2Folks = ["Irma", "Irene", "Ian"];
//        
//        let partyLine = DispatchQueue(label: "party line")
//        let house1Queue = DispatchQueue(label: "house 1", attributes: .concurrent, target: partyLine)
//        let house2Queue = DispatchQueue(label: "house 2", attributes: .concurrent, target: partyLine)
//        
//        for caller in house1Folks {
//            house1Queue.async { [unowned self] in
//                self.makeCall(queue: house1Queue, caller: caller, callees: house2Folks)
//            }
//        }
//        
//        for caller in house2Folks {
//            house2Queue.async { [unowned self] in
//                self.makeCall(queue: house1Queue, caller: caller, callees: house1Folks)
//            }
//        }
        
        return true
    }
    
    func makeCall(queue: DispatchQueue, caller: String, callees: [String]) {
        let targetIndex: Int = Int(arc4random()) % callees.count
        let callee = callees[targetIndex]
        
        print("\(caller) is calling \(callee)")
        sleep(1)
        print("...\(caller) is done calling \(callee)")
        
        queue.asyncAfter(deadline: .now() + (Double(Int(arc4random()) % 1000)) * 0.001) { [unowned self] in
            self.makeCall(queue: queue, caller: caller, callees: callees)
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

