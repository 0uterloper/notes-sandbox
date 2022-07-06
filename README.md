# notes-sandbox

## Priorities
1. **Ramp up on web dev and general maker/hacker mindset**. Just get things working. Make them elegant later, iff it would be valuable. Accepting the right (nonzero) amount of technical debt is a critical meta-systemic tool that I want to grow. And like, figure out what HTTP is and stuff.
2. **Build useful and fun things for myself**. I have ~thousands of markdown notes flatly stored in a folder. A lot of them have good ideas or funny jokes or whatever, and are functionally inaccessible in their current position. Tap this goldmine.
3. **Use [Braid](braid.org)**. I'm sold on their vision and socially intertwined with the team, and I want to learn their paradigm and framework for my own sake while also being a user test case for learning it without already being a web expert.
4. **Build a useful sandbox for other people**. I have conversations all the time with people who put a lot of effort into their PKM models. It would be great to remove a bunch of the friction upstream of building something for yourself. Like uh, make a Twitter bot that auto-tweets from a folder in your Obsidian storage that does something cutesy with your internal links... or something.
5. **Build useful and fun things for other people**. Of course, if I stumble across an idea that I find _exceptionally_ useful or fun, I might clean it up and evangelize it a bit. Host it on a website somewhere where people can sync their Roam graph and use my thing with that data without having to look at code, maybe.

## Project status
I'm **using Obsidian** as my note-taking app. Its key features from my perspective are
1. It stores all notes in a local folder of .md files. No need for an API.
2. It has a good mobile app which supports me frictionlessly getting thoughts down. I liked this about Google Keep before I abandoned it for other reasons. The mobile app syncs with the folder of .md files on my laptop (for a small monthly fee).
3. It's pretty customizable, so I can mold it to my use case. In particular, while I like the "second brain" graph-style stuff, my main use case is a flat bucket-of-notes paradigm (like in Keep), and I can hobble together a UX that suits my needs.

Disclaimer: I am a web dev baby and will probably misuse terms. Hopefully my meaning will be clear, and hopefully this will happen less over time.

Currently I have: 
1. An HTTP server that has a folder of .md files in storage. POST requests write changes to the filesystem. GET requests retrieve files.
2. A synchronizer service that runs POSTs all changes to my Obsidian notes to the server.
3. A fledgling web app that shows a randomly selected note from a specific subdirectory. You can "shelf" the current note to the side, where it can be recalled if you shuffle and grab another note.

## If you want to use any of this
Probably best to reach out to me on Twitter or wherever; my current mindset is not really thinking about usability by someone else yet.

For the bare minimum: you need a folder of .md files as the source of notes. Obsidian does this automatically, but you could also batch export markdown data from some other notes app, or whatever. I'm gonna leave this at "figure it out from there" for now. Low priority to-do to write more here. Let me know if you think I should bump the priority up.