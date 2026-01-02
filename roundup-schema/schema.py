#
# TRACKER SCHEMA
#

# Class automatically gets these properties:
#   creation = Date()
#   activity = Date()
#   creator = Link('user')
#   actor = Link('user')

# The "Minimal" template gets only one class, the required "user"
# class. That's it. And even that has the bare minimum of properties.

# Note: roles is a comma-separated string of Role names
user = Class(db, "user", username=String(), password=Password(),
    address=String(), alternate_addresses=String(), queries=Multilink('query'), roles=String())
user.setkey("username")

category = Class(db, "category", name=String())
category.setkey("name")

prclass = Class(db, "prclass", name=String())
prclass.setkey("name")

priority = Class(db, "priority", name=String())
priority.setkey("name")

severity = Class(db, "severity", name=String())
severity.setkey("name")

state = Class(db, "state", name=String())
state.setkey("name")

# Keywords
keyword = Class(db, "keyword", name=String())
keyword.setkey("name")

query = Class(db, "query",
                klass=String(),
                name=String(),
                url=String(),
                private_for=Link('user'))

# FileClass automatically gets this property in addition to the Class ones:
#   content = String()    [saved to disk in <tracker home>/db/files/]
#   type = String()       [MIME type of the content, default 'text/plain']
msg = FileClass(db, "msg",
        author=Link("user", do_journal='no'),
        recipients=Multilink("user", do_journal='no'),
        date=Date(),
        summary=String(),
        files=Multilink("file"),
        messageid=String(),
        inreplyto=String())

file = FileClass(db, "file",
        name=String())

issue = IssueClass(db, "issue",
        arrivaldate=Date(),
        category=Link("category"),
        prclass=Link("prclass"),
        closeddate=Date(),
        confidential=Boolean(),
        description=String(),
        environment=String(),
        fix=String(),
        howtorepeat=String(),
        lastmod=Date(),
        number=Number(),
        notifylist=String(),
        organization=String(),
        originator=String(),
        priority=Link("priority"),
        release=String(),
        releasenote=String(),
        responsible=String(),
        severity=Link("severity"),
        state=Link("state"),
        submitterid=String(),
        keyword=Multilink("keyword"),
        synopsis=String())

#
# TRACKER SECURITY SETTINGS
#
# See the configuration and customisation document for information
# about security setup.

#
# REGULAR USERS
#
# Give the regular users access to the web and email interface
db.security.addPermissionToRole('User', 'Web Access')
db.security.addPermissionToRole('User', 'Email Access')

# May users view other user information?
# Comment these lines out if you don't want them to
db.security.addPermissionToRole('User', 'View', 'user')

# Users should be able to edit their own details -- this permission is
# limited to only the situation where the Viewed or Edited item is their own.
def own_record(db, userid, itemid):
    '''Determine whether the userid matches the item being accessed.'''
    return userid == itemid
p = db.security.addPermission(name='View', klass='user', check=own_record,
    description="User is allowed to view their own user details")
db.security.addPermissionToRole('User', p)
p = db.security.addPermission(name='Edit', klass='user', check=own_record,
    properties=('username', 'password', 'address', 'alternate_addresses'),
    description="User is allowed to edit their own user details")
db.security.addPermissionToRole('User', p)

#
# ANONYMOUS USER PERMISSIONS
#
# Let anonymous users access the web interface. Note that almost all
# trackers will need this Permission. The only situation where it's not
# required is in a tracker that uses an HTTP Basic Authenticated front-end.
db.security.addPermissionToRole('Anonymous', 'Web Access')

# Let anonymous users access the email interface (note that this implies
# that they will be registered automatically, hence they will need the
# "Create" user Permission below)
#db.security.addPermissionToRole('Anonymous', 'Email Access')

# Assign the appropriate permissions to the anonymous user's
# Anonymous Role. Choices here are:
# - Allow anonymous users to register
#db.security.addPermissionToRole('Anonymous', 'Register', 'user')

# vim: set et sts=4 sw=4 :
#SHA: 1c15b491d82260a13fe170016bf22c015695cd5e
