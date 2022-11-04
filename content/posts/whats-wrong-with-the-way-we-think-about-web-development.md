---
title: "What's Wrong With the Way We Think About Web Development?"
date: 2022-11-04T21:44:01+05:30
draft: false
---

Web development has an abstraction problem. The low-level implementation details
have leaked all the way into code we reguarly write. It's analogous to writing
C or assembly where you need to shape your thinking in terms of the underlying
architecture.

Good abstractions capture thought ideas with only as much bend as is absolutely
needed to eliminate ambiguity. The ideation of a web app is in terms of the
content the user can see and the interactions they can make with the website --
simple. When it goes to implementation however, the developer has to think
analytically and separate what goes into the frontend from what goes into
the backend. This feels very artifical and low-level.

Secondly, it's amazing how much HTML and CSS (or pseudo-CSS like Bootstrap/Tailwind/et al.)
we still write. How many times have you created a form? How many times have you
had to look at the same documentation of forms in whatever CSS framework you use?
It's a problem that has been solved thousands, nay millions of times. Yet we regularly spend
time creating `<form>s`, `<div>s`, caring about its alignment and how it looks on different
screen sizes. We only want something sensible that fits in with our theme and looks OK on
different screen sizes. What we do care about is what content is displayed, what data is
collected from a form, and what happens after submitting it. Context switching to low-level
details takes our attention away from these things.

Thirdly, our database abstractions are not there yet. Databases are essential to most webapps,
and yet they are there by necessity rather than choice. They bring complexity with them.
To maintain them, we have to keep a schema and migrations. We have to write SQL queries that
are performant and at the same time compatible with higher-level language abstractions.
It's a tricky problem to solve. ORMs bring in a different kind of complexity and often
end up hiding performance bottlenecks. For example when you want only the username, an ORM
will likely load all other user data in one shot. The magic they add could have side effects
like loading data from `JOINs` that won't be used later.
