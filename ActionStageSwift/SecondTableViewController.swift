//
//  SecondTableViewController.swift
//  ActionStageSwift
//
//  Created by Hanguang on 2017/3/10.
//  Copyright © 2017年 Hanguang. All rights reserved.
//

import UIKit

class SecondTableViewController: UITableViewController, LHWWatcher {

    var actionHandler: LHWHandler?
    var array: [String] = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        actionHandler = LHWHandler(delegate: self)
        Actor.watchForGenericPath("/mg/newcell/@", watcher: self)
    }

    deinit {
        actionHandler?.reset()
        Actor.removeWatcher(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func addCell() {
        let options = ["text": "new cell (2)"]
        Actor.requestActor(path: "/mg/newcell/(12)", options: options, watcher: self)
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return array.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell2", for: indexPath)

        cell.textLabel?.text = array[indexPath.row]

        return cell
    }
 
    func actionStageResourceDispatched(path: String, resource: Any?, arguments: Any?) {
        if path == "/mg/newcell/(11)" {
            let text = resource as! String
            array.append(text)
            
            LHWDispatchOnMainThread {
                self.tableView.reloadData()
            }
        }
    }

    func actorMessageReceived(path: String, messageType: String?, message: Any?) {
        if path == "/mg/newcell/(11)" {
            LHWDispatchOnMainThread {
                self.addCell()
            }
        }
    }
    
    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
