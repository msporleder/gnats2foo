#
# TRACKER DATABASE INITIALIZATION
#

#unpopulated but we can add categories, etc here to get created at startup
#otherwise you can add them with roundup-admin or the web ui

# create the two default users
user = db.getclass('user')
user.create(username="admin", password=adminpw,
    address=admin_email, roles='Admin')
user.create(username="anonymous", roles='Anonymous')

# add any additional database creation steps here - but only if you
# haven't initialised the database with the admin "initialise" command

# vim: set et sts=4 sw=4 :
#SHA: d1072a54ee12ccbf191b673303231dbe99122787
