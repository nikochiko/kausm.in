---
title: "Local SMTP server for development and testing, with aiosmtpd"
date: 2022-09-21T17:15:43+05:30
draft: false
tags: [dead-simple]
---

Dead simple SMTP server for development and testing.

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
from the config to send an email notification.

I did some research and found aiosmtpd (standard library's [`smtpd`](https://docs.python.org/3/library/smtpd.html)
recommends using this package). All we need to do is:
```
pip3 install aiosmtpd
aiosmtpd -n
```

That's it! An SMTP server is now running on `localhost:8025` and it will print any received emails to console.
That's brilliant if working locally, the default configuration is exactly what we need.
No need for more code to monkeypatch in testing environment, just some configuration changes.

You can even [`netcat`](https://linux.die.net/man/1/nc) to this port and try sending emails
with raw SMTP commands.

# Extending aiosmtpd

If local setup is all you wanted to know about, you can close the blog at this point. But I'll go
on and share how we solved another interesting problem - verifying that code written by our students
was correct and that emails were actually being sent.

Now the caveat is that we were deploying our students' code to a website of their own [[2]]({{< relref "#references" >}})
and the checks should use HTTP endpoints on those websites for checking results. Because we had our
own deployment we had the luxury to be able to override certain environment variables on a per-request
basis without making changes to the application code (CGI is powerful!).

I could write an extension class in less than 50 lines of code that writes the email content to a single
file, and then we can read from the same file to get the latest email. At our scale, this was enough because
it was a very rare case that two people would run their checks at the same time and end up writing over
another's email before the check runs.

This is the code:

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

    def get_latest_message(mail_file):
        """Returns an email.message.Message object

        Useful accessors on Message object:
        `message["X-MailFrom"]`
        `message["X-RcptTo"]`
        `message.get_payload()` -> str | list[str]
        `message.is_multipart()` -> bool
        """
        p = Parser()
        with open(mail_file) as f:
            return p.parse(f)

    @classmethod
    def from_cli(cls, parser, *args):
        # this gets the args received on command line
        if len(args) < 1:
            parser.error("The file for the mailfile is required")
        elif len(args) > 1:
            parser.error("Too many arguments for Mailbox handler")
        return cls(args[0])
```

Then if we package and pip install it as `mailcatcher`, we can write:
```shell
aiosmtpd -n -c mailcatcher.catcher.MailFile latest.mail
```

The reference for extending should be the [`handlers.py`](https://github.com/aio-libs/aiosmtpd/blob/master/aiosmtpd/handlers.py)
file and the [documentation](https://aiosmtpd.readthedocs.io/en/latest/handlers.html).

This is the [`gist`](https://gist.github.com/nikochiko/93650f67235d93b8a35e090a5dcc5fed)

# Unit tests with aiosmtpd

The same class that we wrote can be used for unit testing as well. Except in this case, you might not want to
have a long-running process for the SMTP server, and rather start/stop it for each test.

Here's how you can extend the same mailcatcher to build a pytest fixture which does that:

```python
import pytest
from aiosmtpd.controller import Controller
from mailcatcher import MailFile

from app import config, function_that_should_send_email


@pytest.fixture
def mailcatcher(tmp_path):
    """Fixture to setup a temporary email server

    `tmp_path` is provided by pytest.
    """
    mail_file = tmp_path / "testing.mail"
    catcher = MailFile(mail_file)
    # you can set a different hostname/port as args to `Controller`
    controller = Controller(catcher)
    controller.start()
    config.update(smtp_hostname="localhost", smtp_port="8025",
                  smtp_username="", smtp_password="")
    yield catcher
    controller.stop()


def test_email_is_sent(mailcatcher):
    address = "eva.lu.ator@example.com"

    # procedure to be tested
    function_that_should_send_email(address)

    latest_email = mailcatcher.get_latest_email()
    assert latest_email is not None
    assert latest_email["X-RcptTo"] == address  # or a loose check like `address in latest_email["X-RcptTo"]`
    assert "expected content" in latest_email.get_payload()
```

Again, quite straightforward.

I should mention that [`lazr.smtptest`](https://pythonhosted.org/lazr.smtptest/lazr/smtptest/docs/usage.html)
is also a good alternative with a similar API and workings, made especially for testing.

---

Thanks for reading!
If you liked it or have some feedback, let me know on [Twitter](https://twitter.com/n1kochiko)
or [Telegram](https://t.me/nikochiko).

## References

**[1]** *The training was delivered by [Pipal Academy](https://pipal.in). The guided project in question is open source: [repo link](https://github.com/pipalacademy/rajdhani). This repo has the skeleton needed, and the tasks are mentioned on the [dashboard](https://rajdhani.pipal.in). If you want to host this project and run in your own group, the code for dashboard site is available here: [repo link](https://github.com/pipalacademy/rajdhani-challenge). Let us know and we will help you do it.*

**[2]** *We built our own deployment platform for this, called ["Hamr"](https://github.com/pipalacademy/hamr). We satirically call it the "next-gen" serverless platform. There were philosophical decisions that went into its design and it deserves a blog post of its own.*
