# Our first Hurl file, just checking
# that our server is up and running.
#GET http://rmlsrv01.routementor.com
#HTTP 200

POST https://www.routementor.com/fms/user/login?route=.html
[Form]
user_email: {{fms_email}}
use_pwd: {{fms_password}}
HTTP 200

GET https://www.routementor.com/fms/user/userprofile/viewprofile.html
HTTP 200