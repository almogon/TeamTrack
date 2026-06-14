# Requirements
I want to create an app to manage teams. 
Users:
User has to be unique on the username and the email. They can sign in, and they can log in using username or email.
A users can be the owner of the team but can be also a participant in the same team or in teams created by other users.
I want have a payment subscription system, so each user has a plan. There are 3 plans: free, plus and pro.
With free you can only have or participate in one team, with plus in 3 and pro in 5.
Teams:
Team has a type: Football, basketball, volleyball. Eeach team, has a number of members. (for example in football 5, 7 or 11, in basket only 5...etc)
Players:
For a team exist players. Each team has a maximum and a minimum of players can participate. Football 11 maximum are 18 and minimum are 11.. etc (basic team rules)
A players has a position. A player can not be in more than one position at the same time. Players has a number that is unique per player. Player has a alias. If player is a register user, can choose the alias in the sign in form.

Match:
The idea is control the stats of the match. For that, the user can start a match with a time (base on the match-type; football, volleyball, etc..) and introduce stats during the match.
Stats has rules and points, for example, gol are 5 points, assists 3 points, yellow card -2 points, fault -1 point...
During the match, the user see the position of the players playing with a photo/username, and if type on it, then can set the stat.

The match has a time, and the program should make a pausa on the pausa time as a real sport match. Should notify the user with a notification or something to advise the match stop or finished.