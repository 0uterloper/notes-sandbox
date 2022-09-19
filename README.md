# notes-sandbox
## What is this?
This started as an open-ended project to ramp up on web dev and develop some better systems for organizing my notes (see [Original Priorities](#original-priorities) below).

It has since converged somewhat into a writing tool that I expect to be helpful to at least two people including myself. What follows is a rough description of the tool and its value (which will continue to converge over time, hopefully to something snappy), followed by the original notes guiding this project.

### Main ideas
1. Separate “getting idea down on paper” and “organize and refine writing and spark new ideas” as distinct activity spaces with different priorities that conflict. “Idea down on paper” is a pretty simple problem on its own—just have a very barebones way to take raw notes that’s as accessible as possible. The question then is how to create a second workflow to pipe those notes into to make them as useful as possible
2. [Spaced repetition algorithm](#the-loop) to schedule revisits to notes
3. [Tools](#the-tools) to make the revisit engaging (more gamified/asking for less willpower or focus) and productive
4. Good [version control tools](#version-control) to lead to a work unit that holds onto a lot of process info that often gets lost in the process of refining and auto-generates requests for specific feedback.
5. Really open data model, as unboxed and easy to interact with as possible. If you want to add tags for, say, who you want to give you feedback on this, and write some code to scan notes for people tags and email them every time there's a major edit or something, you should be able to do that using your preferred tools (with as little prescription of tools as possible).

### The loop
1. Take notes in Obsidian. I chose Obsidian because it's very customizable and it stores all note data locally as `.md` files, obviating the need for any interoperability with my system; they communicate through the file system. It's also a very good tool in its own right. (In principle other note-taking apps could be used, but I don't intend to open that box earlier than necessary.)
2. In the shufflenotes app (placeholder name), run a spaced repetition queue through all your notes in the corpus.
	1. Get a note from the queue
	2. Use a number of [tools](#the-tools) to engage with the note
	3. Rate the note on its value and relevance to your current thinking context, putting it back in the queue with a priority weighted by your rating.

### The tools
1. Tagging. Add tags to the note. The most straightforward usage is for organization: Obsidian recognizes the tag format in use here, so adding tags in the shufflenotes app indexes them in Obsidian. The other major usage is for custom functionality that takes actions with notes based on their tags, e.g. if you want notes about people to automatically show a telephone emoji next to their name if they have the "#need-to-call" tag (example courtesy of [this plugin](https://github.com/mdelobelle/obsidian_supercharged_links)). There's a lot of design work to be done here to find actual use cases; I haven't meaningfully started experimenting with this yet.
2. Editing. The note in the app has a link that opens it in Obsidian, where its contents can be edited. Not much more to say here (except that under the current implementation, the  app misbehaves if you rename a note in Obsidian while it's open in shufflenotes 😛).
3. Commentary. You can create a new note that links to the note you're looking at, and open the new note in Obsidian. Here you can write new thoughts that are sparked from looking at your old writing in a new context *without* modifying your original writing.
4. Shelving. You can pin notes to keep them around in short-to-medium-term awareness while you continue through the queue. This has no specific prescribed purpose; I've found it useful in a number of different situations.

### Version control
This is a major feature suite on which development hasn't started, but I anticipate it being core to the final product. For now, a quick nod to the ideas (there's a lot more to say here; for later):
1. Remember process details that went into past work by putting notes-to-self in commit messages. (Think of a lab notebook: it holds all of the notes about specific steps taken to achieve the final result, before any filtering occurs to consider an external audience. Some of what goes in here will be a part of the final work unit, but most of it will not. It's still likely to be valuable information later if you continue to do related work.)
2. Get relevant feedback to works in progress with a tool to aggregate a subsequence of commits into a partial work unit: a diff in the work unit (e.g. a section of a design doc, or a change in framing in an essay) coupled with a selection of commit messages in which you already wrote some notes about *why* you made this change. Draws feedback-givers both to the specific work on which you want feedback and the reasons behind that work.
3. Edit your writing when you have new ideas *without* losing it in its original form, in case in some later context you come to prefer an earlier version. Regular version control stuff.

---
## Original Priorities
This section describes the original principles guiding my open-ended exploration that led to the above ideas:
1. **Ramp up on web dev and general maker/hacker mindset**. Just get things working. Make them elegant later, iff it would be valuable. Accepting the right (nonzero) amount of technical debt is a critical meta-systemic skill that I want to grow. And like, figure out what HTTP is and stuff.
2. **Build useful and fun things for myself**. I have ~thousands of markdown notes flatly stored in a folder. A lot of them have good ideas or funny jokes or whatever, and are functionally inaccessible in their current position. Tap this goldmine.
3. **Use [Braid](https://braid.org)**. I'm sold on their vision and socially intertwined with the team, and I want to learn their paradigm and framework for my own sake while also being a user test case for learning it without already being a web expert.
4. **Build a useful sandbox for other people**. I have conversations all the time with people who put a lot of effort into their PKM models. It would be great to remove a bunch of the friction upstream of building something for yourself. Like uh, make a Twitter bot that auto-tweets from a folder in your Obsidian storage that does something cutesy with your internal links... or something.
5. **Build useful and fun things for other people**. Of course, if I stumble across an idea that I find _exceptionally_ useful or fun, I might clean it up and evangelize it a bit. Host it on a website somewhere where people can sync their Roam graph and use my thing with that data without having to look at code, maybe.
