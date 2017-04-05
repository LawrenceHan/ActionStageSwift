//: Playground - noun: a place where people can play

import UIKit

class User {
    var name: String = ""
}

let user1 = User()
user1.name = "1"

let user2 = User()
user2.name = "2"

let user3 = User()
user3.name = "3"

var users: [User?] = [user1, user2, user3]

var user4: User? = User()
user4?.name = "4"

users.append(user4)
user4 = nil
print(users.count)
