---
title: "Local SMTP server for development and testing, with aiosmtpd"
date: 2022-09-21T17:15:43+05:30
draft: false
tags: [dead-simple]
---

A dead simple way to run a SMTP server for your development environment and testing.

# aiosmtpd for development setup

When we have some code that sends emails, we are faced with the question of what to do for a local
setup. We don't want to send actual emails, but we still want to inspect the contents, senders and
recipients of the email. For example, take any of these common scenarios:
- a verification step where the link is sent by email, and while testing locally, you want
  to quickly find out what it is
- a notification email that you want to verify is being sent correctly
- an email template that you want to verify is being susbtituted correctly

I was recently faced with this when building a guided project for a training [[1]]({{< relref "#references" >}}).
One of the tasks in that project was for the students was to use SMTP credentials
from the config to send an email for a notification. For that reason, the solution
had to be very simple to use.

I did some research and recommended students to do this:
```
pip3 install aiosmtpd
aiosmtpd -n
```

That's it! An SMTP server is now running on `loaclhost:8025` and its default configuration is perfect.

That's brilliant if you are working locally. You don't need to write more code to monkeypatch
the mailer function and stop the SMTP logic from executing. Just change the dev-configuration and it
just works.

You can even [`netcat`](https://linux.die.net/man/1/nc) to this port and try sending emails
with raw handwritten SMTP commands. Now that's something incredibly satisfying.

# Extending aiosmtpd

If local setup is all you wanted to know about, you can close the blog at this point. But I'll go
on and share how we solved another interesting problem - verifying that code written by our students
was correct and that emails were actually being sent.

Now the caveat is that we were deploying our students' code to a website of their own [[2]]({{< relref "#references" >}}). The checks we
had were using API endpoints.

Because we were hosting all our students' sites and our verification site on the same VM (a droplet),
we could start this on localhost and extend the server to log the emails to a file.

That's what we did. Because extending `aiosmtpd` is so simple, I could just write the extension in
a single file in less than 50 lines of code.

```python
# email package is part of the Python standard library,
# which provides an "email.message.Message", along with
# parsers/generators for converting to/from a standard format.
from email.generator import Generator
from email.parser import Parser

# Message class handles all SMTP commands with sensible defaults
# and allows us to only implement a `handle_message` method
# that will be called with a parsed email message
from aiosmtpd.handlers import Message


class MailFile(Message):
    def __init__(self, mail_file, message_class=None):
        # we are taking a mail_file, the path that should be
        # mentioned on the CLI, that we write the mail to
        self.mail_file = mail_file
        super().__init__(message_class=None)

    def handle_message(self, message):
        # overwrite the old file
        with open(self.mail_file, "w") as f:
            # Generator is an abstraction for parsing/writing the
            # email content and the headers
            g = Generator(f, mangle_from_=True, maxheaderlen=120)
            g.flatten(message)

    @classmethod
    def from_cli(cls, parser, *args):
        # this gets the args received on command line
        if len(args) < 1:
            parser.error("The file for the mailfile is required")
        elif len(args) > 1:
            parser.error("Too many arguments for Mailbox handler")
        return cls(args[0])


def get_latest_message(mail_file):
    """Returns email.message.Message class object

    Message class can be used like this:
    `message["X-MailFrom"]`
    `message["X-RcptTo"]`
    `message.get_payload() -> str | list[str]`
    `message.is_multipart() -> bool`
    """
    p = Parser()
    with open(mail_file) as f:
        return p.parse(f)
```

Then if we package and pip install it as `mailcatcher`, we can write:
```shell
aiosmtpd -n -c mailcatcher.catcher.MailFile latest.mail
```

The reference for extending should be the [`handlers.py`](https://github.com/aio-libs/aiosmtpd/blob/master/aiosmtpd/handlers.py)
file and the [documentation](https://aiosmtpd.readthedocs.io/en/latest/handlers.html).

This is the [`gist`](https://gist.github.com/nikochiko/93650f67235d93b8a35e090a5dcc5fed)

Thanks for reading!
If you liked it or have some feedback, let me know on [Twitter](https://twitter.com/n1kochiko)
or [Telegram](https://t.me/nikochiko).

## References

**[1]** *The training was delivered by [Pipal Academy](https://pipal.in). The guided project in question is open source: [repo link](https://github.com/pipalacademy/rajdhani). This repo has the skeleton needed, and the tasks are mentioned on the [dashboard](https://rajdhani.pipal.in). If you want to host this project and run in your own group, the code for dashboard site is available here: [repo link](https://github.com/pipalacademy/rajdhani-challenge). Let us know and we will help you do it.*

**[2]** *We built our own deployment platform for this, called ["Hamr"](https://github.com/pipalacademy/hamr). We satirically call it the "next-gen" serverless platform. There were many philosophical decisions that went into its design. It deserves a blog post of its own.*
